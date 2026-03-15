import 'dispatch_event.dart';

class IntelligenceReceived extends DispatchEvent {
  final String intelligenceId;
  final String provider;
  final String sourceType;
  final String externalId;
  final String clientId;
  final String regionId;
  final String siteId;
  final String? cameraId;
  final String? zone;
  final String? objectLabel;
  final double? objectConfidence;
  final String? faceMatchId;
  final double? faceConfidence;
  final String? plateNumber;
  final double? plateConfidence;
  final String headline;
  final String summary;
  final int riskScore;
  final String? snapshotUrl;
  final String? clipUrl;
  final String canonicalHash;
  final String? snapshotReferenceHash;
  final String? clipReferenceHash;
  final String? evidenceRecordHash;

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
    this.cameraId,
    this.zone,
    this.objectLabel,
    this.objectConfidence,
    this.faceMatchId,
    this.faceConfidence,
    this.plateNumber,
    this.plateConfidence,
    required this.headline,
    required this.summary,
    required this.riskScore,
    this.snapshotUrl,
    this.clipUrl,
    required this.canonicalHash,
    this.snapshotReferenceHash,
    this.clipReferenceHash,
    this.evidenceRecordHash,
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
      cameraId: cameraId,
      zone: zone,
      objectLabel: objectLabel,
      objectConfidence: objectConfidence,
      faceMatchId: faceMatchId,
      faceConfidence: faceConfidence,
      plateNumber: plateNumber,
      plateConfidence: plateConfidence,
      headline: headline,
      summary: summary,
      riskScore: riskScore,
      snapshotUrl: snapshotUrl,
      clipUrl: clipUrl,
      canonicalHash: canonicalHash,
      snapshotReferenceHash: snapshotReferenceHash,
      clipReferenceHash: clipReferenceHash,
      evidenceRecordHash: evidenceRecordHash,
    );
  }
}
