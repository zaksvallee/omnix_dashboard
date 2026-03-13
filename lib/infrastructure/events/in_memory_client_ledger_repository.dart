import '../../domain/evidence/client_ledger_repository.dart';

class InMemoryClientLedgerRepository implements ClientLedgerRepository {
  final Map<String, List<_LedgerRow>> _rowsByClient = {};

  List<Map<String, Object?>> rowsForClient(String clientId) {
    final rows = _rowsByClient[clientId] ?? const <_LedgerRow>[];
    return rows
        .map(
          (row) => <String, Object?>{
            'dispatch_id': row.dispatchId,
            'canonical_json': row.canonicalJson,
            'hash': row.hash,
            'previous_hash': row.previousHash,
          },
        )
        .toList(growable: false);
  }

  @override
  Future<String?> fetchPreviousHash(String clientId) async {
    final rows = _rowsByClient[clientId];
    if (rows == null || rows.isEmpty) return null;
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
        return ClientLedgerRow(
          clientId: clientId,
          dispatchId: row.dispatchId,
          canonicalJson: row.canonicalJson,
          hash: row.hash,
          previousHash: row.previousHash,
        );
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
    final list = _rowsByClient.putIfAbsent(clientId, () => []);
    list.add(
      _LedgerRow(
        dispatchId: dispatchId,
        canonicalJson: canonicalJson,
        hash: hash,
        previousHash: previousHash,
      ),
    );
  }
}

class _LedgerRow {
  final String dispatchId;
  final String canonicalJson;
  final String hash;
  final String? previousHash;

  const _LedgerRow({
    required this.dispatchId,
    required this.canonicalJson,
    required this.hash,
    required this.previousHash,
  });
}
