import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/evidence_certificate_export_service.dart';
import 'package:omnix_dashboard/domain/evidence/client_ledger_service.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/infrastructure/events/in_memory_client_ledger_repository.dart';

void main() {
  test('exports ledger-backed integrity certificate for intelligence', () async {
    final repository = InMemoryClientLedgerRepository();
    final ledgerService = ClientLedgerService(repository);
    final exportService = EvidenceCertificateExportService(repository: repository);

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
      snapshotReferenceHash: 'snap-hash-001',
      clipReferenceHash: 'clip-hash-001',
      evidenceRecordHash: 'evidence-hash-001',
    );

    await ledgerService.sealIntelligenceBatch(events: [event]);

    final export = await exportService.exportForIntelligence(event);

    expect(export.json['certificate_type'], 'onyx_evidence_integrity_certificate');
    final ledger = export.json['ledger'] as Map<String, Object?>;
    expect(ledger['sealed'], isTrue);
    expect(ledger['dispatchId'], 'INTEL-INTEL-001');
    expect((ledger['hash'] as String).isNotEmpty, isTrue);
    expect(export.markdown, contains('Evidence record hash'));
    expect(export.markdown, contains('Ledger hash'));
  });
}
