import '../../domain/evidence/client_ledger_repository.dart';

class InMemoryClientLedgerRepository implements ClientLedgerRepository {
  final Map<String, List<_LedgerRow>> _rowsByClient = {};

  @override
  Future<String?> fetchPreviousHash(String clientId) async {
    final rows = _rowsByClient[clientId];
    if (rows == null || rows.isEmpty) return null;
    return rows.last.hash;
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
