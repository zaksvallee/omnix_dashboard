import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/evidence/client_ledger_repository.dart';

class SupabaseClientLedgerRepository implements ClientLedgerRepository {
  final SupabaseClient client;

  SupabaseClientLedgerRepository(this.client);

  @override
  Future<List<ClientLedgerRow>> listLedgerRows(String clientId) async {
    try {
      final response = await client
          .from('client_evidence_ledger')
          .select('client_id, dispatch_id, canonical_json, hash, previous_hash')
          .eq('client_id', clientId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map(
            (row) => ClientLedgerRow(
              clientId: (row['client_id'] ?? '').toString(),
              dispatchId: (row['dispatch_id'] ?? '').toString(),
              canonicalJson: (row['canonical_json'] ?? '').toString(),
              hash: (row['hash'] ?? '').toString(),
              previousHash: row['previous_hash'] as String?,
            ),
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to list client ledger rows for $clientId.',
        name: 'SupabaseClientLedgerRepository',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

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
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch previous client ledger hash for $clientId.',
        name: 'SupabaseClientLedgerRepository',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<ClientLedgerRow?> fetchLedgerRow({
    required String clientId,
    required String dispatchId,
  }) async {
    try {
      final response = await client
          .from('client_evidence_ledger')
          .select('client_id, dispatch_id, canonical_json, hash, previous_hash')
          .eq('client_id', clientId)
          .eq('dispatch_id', dispatchId)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return ClientLedgerRow(
        clientId: (response['client_id'] ?? '').toString(),
        dispatchId: (response['dispatch_id'] ?? '').toString(),
        canonicalJson: (response['canonical_json'] ?? '').toString(),
        hash: (response['hash'] ?? '').toString(),
        previousHash: response['previous_hash'] as String?,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch client ledger row for $clientId/$dispatchId.',
        name: 'SupabaseClientLedgerRepository',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
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
    } catch (error, stackTrace) {
      developer.log(
        'Failed to insert client ledger row for $clientId/$dispatchId.',
        name: 'SupabaseClientLedgerRepository',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
