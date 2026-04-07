import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/evidence/client_ledger_repository.dart';
import 'package:omnix_dashboard/domain/evidence/client_ledger_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/execution_completed.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/infrastructure/events/in_memory_client_ledger_repository.dart';

void main() {
  test('seals intelligence provenance rows into the client ledger', () async {
    final repository = InMemoryClientLedgerRepository();
    final service = ClientLedgerService(repository);

    await service.sealIntelligenceBatch(events: [_intelligenceEvent()]);

    final rows = repository.rowsForClient('CLIENT-001');
    expect(rows, hasLength(1));
    expect(rows.single['dispatch_id'], 'INTEL-INTEL-001');
    final payload =
        jsonDecode(rows.single['canonical_json']! as String)
            as Map<String, Object?>;
    expect(payload['type'], 'intelligence_evidence_provenance');
    expect(payload['intelligenceId'], 'INTEL-001');
    expect(payload['evidenceRecordHash'], 'evidence-hash-001');
  });

  test(
    'sealDispatch stores human-readable event JSON instead of instance strings',
    () async {
      final repository = InMemoryClientLedgerRepository();
      final service = ClientLedgerService(repository);

      await service.sealDispatch(
        clientId: 'CLIENT-001',
        dispatchId: 'DSP-001',
        events: [
          DecisionCreated(
            eventId: 'DEC-1',
            sequence: 1,
            version: 1,
            occurredAt: DateTime.utc(2026, 4, 7, 8, 0),
            dispatchId: 'DSP-001',
            clientId: 'CLIENT-001',
            regionId: 'REGION-1',
            siteId: 'SITE-1',
          ),
          ExecutionCompleted(
            eventId: 'EXEC-1',
            sequence: 2,
            version: 1,
            occurredAt: DateTime.utc(2026, 4, 7, 8, 2),
            dispatchId: 'DSP-001',
            clientId: 'CLIENT-001',
            regionId: 'REGION-1',
            siteId: 'SITE-1',
            success: true,
          ),
        ],
      );

      final row = await repository.fetchLedgerRow(
        clientId: 'CLIENT-001',
        dispatchId: 'DSP-001',
      );
      expect(row, isNotNull);
      expect(
        row!.canonicalJson,
        isNot(contains("Instance of 'DecisionCreated'")),
      );
      final payload = jsonDecode(row.canonicalJson) as Map<String, Object?>;
      final events = (payload['events'] as List<Object?>)
          .cast<Map<Object?, Object?>>();
      expect(events, hasLength(2));
      expect(events.first['type'], 'decision_created');
      expect(events.first['dispatchId'], 'DSP-001');
      expect(events.last['type'], 'execution_completed');
      expect(events.last['success'], true);
    },
  );

  test(
    'sealIntelligenceBatch is idempotent for repeated event batches',
    () async {
      final repository = InMemoryClientLedgerRepository();
      final service = ClientLedgerService(repository);
      final event = _intelligenceEvent();

      await service.sealIntelligenceBatch(events: [event]);
      await service.sealIntelligenceBatch(events: [event]);

      final rows = repository.rowsForClient('CLIENT-001');
      expect(rows, hasLength(1));
      expect(rows.single['dispatch_id'], 'INTEL-INTEL-001');
    },
  );

  test(
    'queues evidence when previous-hash lookup fails and flushes in order on recovery',
    () async {
      final repository = _FlakyLedgerRepository(failPreviousHash: true);
      final service = ClientLedgerService(repository);

      await service.sealIntelligenceBatch(events: [_intelligenceEvent()]);
      expect(repository.rowsForClient('CLIENT-001'), isEmpty);

      repository.failPreviousHash = false;
      await service.sealCanonicalRecord(
        clientId: 'CLIENT-001',
        recordId: 'CANON-002',
        canonicalPayload: const {
          'type': 'manual_entry',
          'recorded_at_utc': '2026-04-07T08:30:00.000Z',
        },
      );

      final rows = repository.rowsForClient('CLIENT-001');
      expect(rows.map((row) => row.dispatchId), [
        'INTEL-INTEL-001',
        'CANON-002',
      ]);
    },
  );

  test(
    'queues evidence when insert fails and flushes in order on recovery',
    () async {
      final repository = _FlakyLedgerRepository(failInsert: true);
      final service = ClientLedgerService(repository);

      await service.sealIntelligenceBatch(events: [_intelligenceEvent()]);
      expect(repository.rowsForClient('CLIENT-001'), isEmpty);

      repository.failInsert = false;
      await service.sealCanonicalRecord(
        clientId: 'CLIENT-001',
        recordId: 'CANON-003',
        canonicalPayload: const {
          'type': 'manual_entry',
          'recorded_at_utc': '2026-04-07T08:45:00.000Z',
        },
      );

      final rows = repository.rowsForClient('CLIENT-001');
      expect(rows.map((row) => row.dispatchId), [
        'INTEL-INTEL-001',
        'CANON-003',
      ]);
    },
  );
}

IntelligenceReceived _intelligenceEvent() {
  return IntelligenceReceived(
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
}

class _FlakyLedgerRepository implements ClientLedgerRepository {
  bool failPreviousHash;
  bool failInsert;
  final Map<String, List<ClientLedgerRow>> _rowsByClient =
      <String, List<ClientLedgerRow>>{};

  _FlakyLedgerRepository({
    this.failPreviousHash = false,
    this.failInsert = false,
  });

  List<ClientLedgerRow> rowsForClient(String clientId) {
    return List<ClientLedgerRow>.from(
      _rowsByClient[clientId] ?? const <ClientLedgerRow>[],
    );
  }

  @override
  Future<List<ClientLedgerRow>> listLedgerRows(String clientId) async {
    return rowsForClient(clientId);
  }

  @override
  Future<String?> fetchPreviousHash(String clientId) async {
    if (failPreviousHash) {
      throw StateError('previous hash unavailable');
    }
    final rows = _rowsByClient[clientId];
    if (rows == null || rows.isEmpty) {
      return null;
    }
    return rows.last.hash;
  }

  @override
  Future<ClientLedgerRow?> fetchLedgerRow({
    required String clientId,
    required String dispatchId,
  }) async {
    final rows = _rowsByClient[clientId];
    if (rows == null) {
      return null;
    }
    for (final row in rows) {
      if (row.dispatchId == dispatchId) {
        return row;
      }
    }
    return null;
  }

  @override
  Future<void> insertLedgerRow({
    required String clientId,
    required String dispatchId,
    required String canonicalJson,
    required String hash,
    String? previousHash,
  }) async {
    if (failInsert) {
      throw StateError('insert unavailable');
    }
    final rows = _rowsByClient.putIfAbsent(clientId, () => <ClientLedgerRow>[]);
    rows.add(
      ClientLedgerRow(
        clientId: clientId,
        dispatchId: dispatchId,
        canonicalJson: canonicalJson,
        hash: hash,
        previousHash: previousHash,
      ),
    );
  }
}
