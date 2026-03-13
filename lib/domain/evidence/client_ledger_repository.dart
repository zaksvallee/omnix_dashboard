class ClientLedgerRow {
  final String clientId;
  final String dispatchId;
  final String canonicalJson;
  final String hash;
  final String? previousHash;

  const ClientLedgerRow({
    required this.clientId,
    required this.dispatchId,
    required this.canonicalJson,
    required this.hash,
    this.previousHash,
  });
}

abstract class ClientLedgerRepository {
  Future<String?> fetchPreviousHash(String clientId);

  Future<ClientLedgerRow?> fetchLedgerRow({
    required String clientId,
    required String dispatchId,
  });

  Future<void> insertLedgerRow({
    required String clientId,
    required String dispatchId,
    required String canonicalJson,
    required String hash,
    String? previousHash,
  });
}
