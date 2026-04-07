import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/evidence_certificate_export_service.dart';
import 'package:omnix_dashboard/domain/evidence/client_ledger_service.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/infrastructure/events/in_memory_client_ledger_repository.dart';

void main() {
  test('computes chained payload hash for ledger exports', () {
    final hash = EvidenceCertificateExportService.chainedPayloadHash(
      payload: const <String, Object?>{
        'source': 'manual_ob_entry',
        'clientId': 'CLIENT-001',
        'site': 'HQ',
        'guard_name': 'Alex',
        'callsign': 'BRAVO-2',
        'location_detail': 'North gate',
        'description': 'Alarm acknowledged',
        'category': 'alarm',
        'flagged': true,
        'refined': true,
      },
      previousHash: 'abc123prev',
    );

    expect(
      hash,
      '5f59e2c01a044fbc16d11d5c18e7555acb4e623724b4f4a050a00f6b4b7da5d3',
    );
  });

  test(
    'exports ledger-backed integrity certificate for intelligence',
    () async {
      final repository = InMemoryClientLedgerRepository();
      final ledgerService = ClientLedgerService(repository);
      final exportService = EvidenceCertificateExportService(
        repository: repository,
        ledgerService: ledgerService,
      );

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

      expect(
        export.json['certificate_type'],
        'onyx_evidence_integrity_certificate',
      );
      final ledger = export.json['ledger'] as Map<String, Object?>;
      expect(ledger['sealed'], isTrue);
      expect(ledger['hashVerified'], isTrue);
      expect(ledger['dispatchId'], 'INTEL-INTEL-001');
      expect((ledger['hash'] as String).isNotEmpty, isTrue);
      expect(export.markdown, contains('Evidence record hash'));
      expect(export.markdown, contains('Ledger hash'));
    },
  );

  test(
    'refuses export when stored ledger hash does not match canonical payload',
    () async {
      final repository = InMemoryClientLedgerRepository();
      final exportService = EvidenceCertificateExportService(
        repository: repository,
      );

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

      await repository.insertLedgerRow(
        clientId: 'CLIENT-001',
        dispatchId: ClientLedgerService.intelligenceLedgerDispatchId(
          'INTEL-001',
        ),
        canonicalJson:
            '{"type":"intelligence_evidence_provenance","intelligenceId":"INTEL-001"}',
        hash: 'tampered-hash',
        previousHash: null,
      );

      await expectLater(
        exportService.exportForIntelligence(event),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Ledger tamper detected'),
          ),
        ),
      );
    },
  );
}
