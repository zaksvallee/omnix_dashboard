import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../events/intelligence_received.dart';

String _sha256Hex(String value) {
  return sha256.convert(Uint8List.fromList(utf8.encode(value))).toString();
}

String evidenceLocatorHash(String? locator) {
  final normalized = (locator ?? '').trim();
  if (normalized.isEmpty) {
    return '';
  }
  return _sha256Hex(normalized);
}

String buildEvidenceRecordHash({
  required String canonicalHash,
  required String provider,
  required String sourceType,
  required String externalId,
  required String clientId,
  required String regionId,
  required String siteId,
  required DateTime occurredAtUtc,
  String? snapshotReferenceHash,
  String? clipReferenceHash,
}) {
  final payload = <String, Object?>{
    'canonicalHash': canonicalHash,
    'provider': provider.trim(),
    'sourceType': sourceType.trim(),
    'externalId': externalId.trim(),
    'clientId': clientId.trim(),
    'regionId': regionId.trim(),
    'siteId': siteId.trim(),
    'occurredAtUtc': occurredAtUtc.toUtc().toIso8601String(),
    'snapshotReferenceHash': (snapshotReferenceHash ?? '').trim(),
    'clipReferenceHash': (clipReferenceHash ?? '').trim(),
  };
  return _sha256Hex(jsonEncode(payload));
}

class EvidenceLocatorProvenance {
  final String kind;
  final String locator;
  final String locatorHash;

  const EvidenceLocatorProvenance({
    required this.kind,
    required this.locator,
    required this.locatorHash,
  });

  bool get isPresent => locator.trim().isNotEmpty;

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      'locator': locator,
      'locatorHash': locatorHash,
      'present': isPresent,
    };
  }
}

class EvidenceProvenanceCertificate {
  final String intelligenceId;
  final String provider;
  final String sourceType;
  final String externalId;
  final String clientId;
  final String regionId;
  final String siteId;
  final DateTime occurredAtUtc;
  final String canonicalHash;
  final String evidenceRecordHash;
  final EvidenceLocatorProvenance snapshot;
  final EvidenceLocatorProvenance clip;

  const EvidenceProvenanceCertificate({
    required this.intelligenceId,
    required this.provider,
    required this.sourceType,
    required this.externalId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.occurredAtUtc,
    required this.canonicalHash,
    required this.evidenceRecordHash,
    required this.snapshot,
    required this.clip,
  });

  factory EvidenceProvenanceCertificate.fromIntelligence(
    IntelligenceReceived event,
  ) {
    final snapshotHash = (event.snapshotReferenceHash ?? '').trim().isNotEmpty
        ? event.snapshotReferenceHash!.trim()
        : evidenceLocatorHash(event.snapshotUrl);
    final clipHash = (event.clipReferenceHash ?? '').trim().isNotEmpty
        ? event.clipReferenceHash!.trim()
        : evidenceLocatorHash(event.clipUrl);
    final evidenceHash = (event.evidenceRecordHash ?? '').trim().isNotEmpty
        ? event.evidenceRecordHash!.trim()
        : buildEvidenceRecordHash(
            canonicalHash: event.canonicalHash,
            provider: event.provider,
            sourceType: event.sourceType,
            externalId: event.externalId,
            clientId: event.clientId,
            regionId: event.regionId,
            siteId: event.siteId,
            occurredAtUtc: event.occurredAt,
            snapshotReferenceHash: snapshotHash,
            clipReferenceHash: clipHash,
          );

    return EvidenceProvenanceCertificate(
      intelligenceId: event.intelligenceId,
      provider: event.provider,
      sourceType: event.sourceType,
      externalId: event.externalId,
      clientId: event.clientId,
      regionId: event.regionId,
      siteId: event.siteId,
      occurredAtUtc: event.occurredAt.toUtc(),
      canonicalHash: event.canonicalHash,
      evidenceRecordHash: evidenceHash,
      snapshot: EvidenceLocatorProvenance(
        kind: 'snapshot',
        locator: (event.snapshotUrl ?? '').trim(),
        locatorHash: snapshotHash,
      ),
      clip: EvidenceLocatorProvenance(
        kind: 'clip',
        locator: (event.clipUrl ?? '').trim(),
        locatorHash: clipHash,
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'intelligenceId': intelligenceId,
      'provider': provider,
      'sourceType': sourceType,
      'externalId': externalId,
      'clientId': clientId,
      'regionId': regionId,
      'siteId': siteId,
      'occurredAtUtc': occurredAtUtc.toUtc().toIso8601String(),
      'canonicalHash': canonicalHash,
      'evidenceRecordHash': evidenceRecordHash,
      'locators': {
        'snapshot': snapshot.toJson(),
        'clip': clip.toJson(),
      },
    };
  }
}
