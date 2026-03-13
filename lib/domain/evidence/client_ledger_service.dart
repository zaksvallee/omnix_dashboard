import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import '../events/dispatch_event.dart';
import '../events/decision_created.dart';
import '../events/execution_completed.dart';
import '../events/intelligence_received.dart';
import 'evidence_provenance.dart';
import 'client_ledger_repository.dart';

class ClientLedgerService {
  final ClientLedgerRepository repository;

  ClientLedgerService(this.repository);

  static String intelligenceLedgerDispatchId(String intelligenceId) {
    return 'INTEL-$intelligenceId';
  }

  Future<void> _sealCanonical({
    required String clientId,
    required String recordId,
    required Map<String, Object?> canonicalPayload,
  }) async {
    final canonicalJson = jsonEncode(canonicalPayload);
    final previousHash = await repository.fetchPreviousHash(clientId);
    final combined = previousHash == null ? canonicalJson : canonicalJson + previousHash;
    final hash = sha256
        .convert(Uint8List.fromList(utf8.encode(combined)))
        .toString();

    await repository.insertLedgerRow(
      clientId: clientId,
      dispatchId: recordId,
      canonicalJson: canonicalJson,
      hash: hash,
      previousHash: previousHash,
    );
  }

  Future<void> sealDispatch({
    required String clientId,
    required String dispatchId,
    required List<DispatchEvent> events,
  }) async {
    final relevant = events.where((e) {
      if (e is DecisionCreated) {
        return e.dispatchId == dispatchId;
      }
      if (e is ExecutionCompleted) {
        return e.dispatchId == dispatchId;
      }
      return false;
    }).toList();

    final canonicalJson = jsonEncode({
      "clientId": clientId,
      "dispatchId": dispatchId,
      "events": relevant.map((e) => e.toString()).toList(),
    });
    await _sealCanonical(
      clientId: clientId,
      recordId: dispatchId,
      canonicalPayload: jsonDecode(canonicalJson) as Map<String, Object?>,
    );
  }

  Future<void> sealIntelligenceBatch({
    required Iterable<IntelligenceReceived> events,
  }) async {
    final sorted = [...events]
      ..sort((a, b) {
        final ts = a.occurredAt.compareTo(b.occurredAt);
        if (ts != 0) return ts;
        return a.intelligenceId.compareTo(b.intelligenceId);
      });

    for (final event in sorted) {
      final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
      await _sealCanonical(
        clientId: event.clientId,
        recordId: intelligenceLedgerDispatchId(event.intelligenceId),
        canonicalPayload: {
          'type': 'intelligence_evidence_provenance',
          ...certificate.toJson(),
        },
      );
    }
  }
}
