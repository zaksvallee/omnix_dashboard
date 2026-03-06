abstract class ClientLedgerRepository {
  Future<String?> fetchPreviousHash(String clientId);

  Future<void> insertLedgerRow({
    required String clientId,
    required String dispatchId,
    required String canonicalJson,
    required String hash,
    String? previousHash,
  });
}
