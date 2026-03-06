import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/evidence/client_ledger_repository.dart';

class SupabaseClientLedgerRepository implements ClientLedgerRepository {
  final SupabaseClient client;

  SupabaseClientLedgerRepository(this.client);

  @override
  Future<String?> fetchPreviousHash(String clientId) async {
    try {
      final response = await client
          .from('client_evidence_ledger')
          .select('hash')
          .eq('client_id', clientId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return response['hash'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insertLedgerRow({
    required String clientId,
    required String dispatchId,
    required String canonicalJson,
    required String hash,
    String? previousHash,
  }) async {
    try {
      await client.from('client_evidence_ledger').insert({
        'client_id': clientId,
        'dispatch_id': dispatchId,
        'canonical_json': canonicalJson,
        'hash': hash,
        'previous_hash': previousHash,
      });
    } catch (_) {
      // Keep command flow active even when external ledger infra is unavailable.
    }
  }
}
