import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../events/decision_created.dart';
import '../events/dispatch_event.dart';
import '../events/execution_completed.dart';
import '../events/intelligence_received.dart';
import 'client_ledger_repository.dart';
import 'evidence_provenance.dart';

String _sha256Hex(String value) {
  return sha256.convert(Uint8List.fromList(utf8.encode(value))).toString();
}

class ClientLedgerService {
  final ClientLedgerRepository repository;
  final List<_PendingLedgerSeal> _pendingSeals = <_PendingLedgerSeal>[];

  ClientLedgerService(this.repository);

  static String intelligenceLedgerDispatchId(String intelligenceId) {
    return 'INTEL-$intelligenceId';
  }

  static String ledgerHashFor({
    required String canonicalJson,
    String? previousHash,
  }) {
    final combined = previousHash == null
        ? canonicalJson
        : canonicalJson + previousHash;
    return sha256.convert(Uint8List.fromList(utf8.encode(combined))).toString();
  }

  Future<void> flushPendingEvidence() async {
    if (_pendingSeals.isEmpty) {
      return;
    }
    final queued = List<_PendingLedgerSeal>.from(_pendingSeals);
    for (final seal in queued) {
      try {
        await _persistCanonical(seal);
        _pendingSeals.remove(seal);
      } catch (error, stackTrace) {
        developer.log(
          'Failed to flush queued ledger evidence for ${seal.clientId}/${seal.recordId} (${seal.idempotencyKey}).',
          name: 'ClientLedgerService',
          error: error,
          stackTrace: stackTrace,
        );
        return;
      }
    }
  }

  Future<ClientLedgerRow?> _sealCanonical({
    required String clientId,
    required String recordId,
    required String idempotencyKey,
    required Map<String, Object?> canonicalPayload,
  }) async {
    await flushPendingEvidence();
    final seal = _PendingLedgerSeal(
      clientId: clientId,
      recordId: recordId,
      idempotencyKey: idempotencyKey,
      canonicalPayload: canonicalPayload,
    );
    try {
      return await _persistCanonical(seal);
    } catch (error, stackTrace) {
      _queuePendingSeal(seal, error, stackTrace);
      return null;
    }
  }

  Future<ClientLedgerRow> _persistCanonical(_PendingLedgerSeal seal) async {
    final existing = await repository.fetchLedgerRow(
      clientId: seal.clientId,
      dispatchId: seal.recordId,
    );
    if (existing != null) {
      return existing;
    }

    final canonicalJson = jsonEncode(seal.canonicalPayload);
    final previousHash = await repository.fetchPreviousHash(seal.clientId);
    final hash = ledgerHashFor(
      canonicalJson: canonicalJson,
      previousHash: previousHash,
    );

    await repository.insertLedgerRow(
      clientId: seal.clientId,
      dispatchId: seal.recordId,
      canonicalJson: canonicalJson,
      hash: hash,
      previousHash: previousHash,
    );

    return ClientLedgerRow(
      clientId: seal.clientId,
      dispatchId: seal.recordId,
      canonicalJson: canonicalJson,
      hash: hash,
      previousHash: previousHash,
    );
  }

  void _queuePendingSeal(
    _PendingLedgerSeal seal,
    Object error,
    StackTrace stackTrace,
  ) {
    final alreadyQueued = _pendingSeals.any(
      (entry) =>
          entry.clientId == seal.clientId &&
          entry.recordId == seal.recordId &&
          entry.idempotencyKey == seal.idempotencyKey,
    );
    if (!alreadyQueued) {
      _pendingSeals.add(seal);
    }
    developer.log(
      'Queued ledger evidence for retry after persistence failure: ${seal.clientId}/${seal.recordId} (${seal.idempotencyKey}).',
      name: 'ClientLedgerService',
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<ClientLedgerRow?> sealCanonicalRecord({
    required String clientId,
    required String recordId,
    required Map<String, Object?> canonicalPayload,
    String? idempotencyKey,
  }) async {
    return _sealCanonical(
      clientId: clientId,
      recordId: recordId,
      idempotencyKey:
          idempotencyKey ??
          _canonicalRecordIdempotencyKey(
            clientId: clientId,
            recordId: recordId,
            canonicalPayload: canonicalPayload,
          ),
      canonicalPayload: canonicalPayload,
    );
  }

  Future<ClientLedgerRow?> sealDispatch({
    required String clientId,
    required String dispatchId,
    required List<DispatchEvent> events,
  }) async {
    final relevant = events
        .where((event) {
          if (event is DecisionCreated) {
            return event.dispatchId == dispatchId;
          }
          if (event is ExecutionCompleted) {
            return event.dispatchId == dispatchId;
          }
          return false;
        })
        .toList(growable: false);

    final latestRelevant = relevant.isEmpty
        ? null
        : (List<DispatchEvent>.from(
            relevant,
          )..sort((a, b) => a.occurredAt.compareTo(b.occurredAt))).last;

    return _sealCanonical(
      clientId: clientId,
      recordId: dispatchId,
      idempotencyKey: latestRelevant == null
          ? 'dispatch|$clientId|$dispatchId|empty'
          : 'dispatch|$clientId|${latestRelevant.eventId}|${latestRelevant.occurredAt.toUtc().toIso8601String()}',
      canonicalPayload: {
        'clientId': clientId,
        'dispatchId': dispatchId,
        'events': relevant.map(_dispatchEventJson).toList(growable: false),
      },
    );
  }

  Future<void> sealIntelligenceBatch({
    required Iterable<IntelligenceReceived> events,
  }) async {
    final sorted = [...events]
      ..sort((a, b) {
        final ts = a.occurredAt.compareTo(b.occurredAt);
        if (ts != 0) {
          return ts;
        }
        return a.intelligenceId.compareTo(b.intelligenceId);
      });

    for (final event in sorted) {
      final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
      await _sealCanonical(
        clientId: event.clientId,
        recordId: intelligenceLedgerDispatchId(event.intelligenceId),
        idempotencyKey:
            'intelligence|${event.clientId}|${event.eventId}|${event.occurredAt.toUtc().toIso8601String()}',
        canonicalPayload: {
          'type': 'intelligence_evidence_provenance',
          ...certificate.toJson(),
        },
      );
    }
  }

  String _canonicalRecordIdempotencyKey({
    required String clientId,
    required String recordId,
    required Map<String, Object?> canonicalPayload,
  }) {
    return _sha256Hex(
      jsonEncode({
        'clientId': clientId.trim(),
        'recordId': recordId.trim(),
        'payload': canonicalPayload,
      }),
    );
  }

  Map<String, Object?> _dispatchEventJson(DispatchEvent event) {
    if (event is DecisionCreated) {
      return event.toJson();
    }
    if (event is ExecutionCompleted) {
      return event.toJson();
    }
    return {
      'type': event.toAuditTypeKey(),
      'eventId': event.eventId,
      'sequence': event.sequence,
      'version': event.version,
      'occurredAtUtc': event.occurredAt.toUtc().toIso8601String(),
      'detail': event.toString(),
    };
  }
}

class _PendingLedgerSeal {
  final String clientId;
  final String recordId;
  final String idempotencyKey;
  final Map<String, Object?> canonicalPayload;

  const _PendingLedgerSeal({
    required this.clientId,
    required this.recordId,
    required this.idempotencyKey,
    required this.canonicalPayload,
  });
}
