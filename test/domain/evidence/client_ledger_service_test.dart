import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/evidence/client_ledger_service.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/infrastructure/events/in_memory_client_ledger_repository.dart';

void main() {
  test('seals intelligence provenance rows into the client ledger', () async {
    final repository = InMemoryClientLedgerRepository();
    final service = ClientLedgerService(repository);

    await service.sealIntelligenceBatch(
      events: [
        IntelligenceReceived(
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
          snapshotReferenceHash: 'snap-hash-001',
          clipReferenceHash: 'clip-hash-001',
          evidenceRecordHash: 'evidence-hash-001',
        ),
      ],
    );

    final rows = repository.rowsForClient('CLIENT-001');
    expect(rows, hasLength(1));
    expect(rows.single['dispatch_id'], 'INTEL-INTEL-001');
    final payload = jsonDecode(rows.single['canonical_json']! as String)
        as Map<String, Object?>;
    expect(payload['type'], 'intelligence_evidence_provenance');
    expect(payload['intelligenceId'], 'INTEL-001');
    expect(payload['evidenceRecordHash'], 'evidence-hash-001');
  });
}
