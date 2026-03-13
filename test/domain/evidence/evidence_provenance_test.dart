import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/evidence/evidence_provenance.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  test('builds deterministic provenance certificate from intelligence event', () {
    final event = IntelligenceReceived(
      eventId: 'INT-1',
      sequence: 1,
      version: 1,
      occurredAt: DateTime.utc(2026, 3, 13, 9, 15),
      intelligenceId: 'INTEL-001',
      provider: 'frigate',
      sourceType: 'hardware',
      externalId: 'evt-1',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
      headline: 'FRIGATE INTRUSION',
      summary: 'Person detected in north_gate',
      riskScore: 94,
      snapshotUrl: 'https://edge.example.com/api/events/evt-1/snapshot.jpg',
      clipUrl: 'https://edge.example.com/api/events/evt-1/clip.mp4',
      canonicalHash: 'canon-hash-001',
      snapshotReferenceHash: evidenceLocatorHash(
        'https://edge.example.com/api/events/evt-1/snapshot.jpg',
      ),
      clipReferenceHash: evidenceLocatorHash(
        'https://edge.example.com/api/events/evt-1/clip.mp4',
      ),
      evidenceRecordHash: buildEvidenceRecordHash(
        canonicalHash: 'canon-hash-001',
        provider: 'frigate',
        sourceType: 'hardware',
        externalId: 'evt-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        occurredAtUtc: DateTime.utc(2026, 3, 13, 9, 15),
        snapshotReferenceHash: evidenceLocatorHash(
          'https://edge.example.com/api/events/evt-1/snapshot.jpg',
        ),
        clipReferenceHash: evidenceLocatorHash(
          'https://edge.example.com/api/events/evt-1/clip.mp4',
        ),
      ),
    );

    final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
    final json = certificate.toJson();

    expect(json['canonicalHash'], 'canon-hash-001');
    expect(json['evidenceRecordHash'], isNotEmpty);
    expect(
      ((json['locators'] as Map<String, Object?>)['snapshot']
          as Map<String, Object?>)['locatorHash'],
      evidenceLocatorHash('https://edge.example.com/api/events/evt-1/snapshot.jpg'),
    );
    expect(
      ((json['locators'] as Map<String, Object?>)['clip']
          as Map<String, Object?>)['locatorHash'],
      evidenceLocatorHash('https://edge.example.com/api/events/evt-1/clip.mp4'),
    );
  });
}
