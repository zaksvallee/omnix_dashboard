import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import '../events/dispatch_event.dart';
import '../events/decision_created.dart';
import '../events/execution_completed.dart';
import 'client_ledger_repository.dart';

class ClientLedgerService {
  final ClientLedgerRepository repository;

  ClientLedgerService(this.repository);

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

    final previousHash =
        await repository.fetchPreviousHash(clientId);

    final combined =
        previousHash == null ? canonicalJson : canonicalJson + previousHash;

    final hash = sha256
        .convert(Uint8List.fromList(utf8.encode(combined)))
        .toString();

    await repository.insertLedgerRow(
      clientId: clientId,
      dispatchId: dispatchId,
      canonicalJson: canonicalJson,
      hash: hash,
      previousHash: previousHash,
    );
  }
}
