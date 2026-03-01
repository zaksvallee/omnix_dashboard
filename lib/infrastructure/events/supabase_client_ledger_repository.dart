import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientLedgerRepository {
  final SupabaseClient client;

  SupabaseClientLedgerRepository(this.client);

  Future<String?> fetchPreviousHash(String clientId) async {
    final response = await client
        .from('client_evidence_ledger')
        .select('hash')
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    return response['hash'] as String?;
  }

  Future<void> insertLedgerRow({
    required String clientId,
    required String dispatchId,
    required String canonicalJson,
    required String hash,
    String? previousHash,
  }) async {
    await client.from('client_evidence_ledger').insert({
      'client_id': clientId,
      'dispatch_id': dispatchId,
      'canonical_json': canonicalJson,
      'hash': hash,
      'previous_hash': previousHash,
    });
  }
}
