import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:omnix_dashboard/infrastructure/events/supabase_client_ledger_repository.dart';

void main() {
  test(
    'fetchPreviousHash rethrows ledger query failures instead of swallowing them',
    () async {
      final repository = SupabaseClientLedgerRepository(
        _buildSupabaseClient((request) async {
          return http.Response(
            '{"message":"ledger unavailable"}',
            500,
            request: request,
          );
        }),
      );

      await expectLater(
        repository.fetchPreviousHash('CLIENT-001'),
        throwsA(anything),
      );
    },
  );

  test(
    'insertLedgerRow rethrows insert failures instead of swallowing them',
    () async {
      final repository = SupabaseClientLedgerRepository(
        _buildSupabaseClient((request) async {
          return http.Response(
            '{"message":"insert failed"}',
            500,
            request: request,
          );
        }),
      );

      await expectLater(
        repository.insertLedgerRow(
          clientId: 'CLIENT-001',
          dispatchId: 'DISPATCH-001',
          canonicalJson: '{"type":"test"}',
          hash: 'hash-001',
          previousHash: null,
        ),
        throwsA(anything),
      );
    },
  );
}

SupabaseClient _buildSupabaseClient(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    accessToken: () async => null,
    httpClient: MockClient(handler),
  );
}
