import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/alarm_account_registry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('AlarmAccountRegistry resolves account bindings from Supabase', () async {
    final registry = AlarmAccountRegistry(
      client: _buildSupabaseClient((request) async {
        if (request.url.path.endsWith('/alarm_accounts')) {
          return http.Response(
            '[{"account_number":"1234","client_id":"CLIENT-A","site_id":"SITE-A","aes_key_override":"00112233445566778899AABBCCDDEEFF"}]',
            200,
            request: request,
          );
        }
        return http.Response('[]', 200, request: request);
      }),
    );

    final binding = await registry.resolve('1234');

    expect(binding, isNotNull);
    expect(binding!.clientId, 'CLIENT-A');
    expect(binding.siteId, 'SITE-A');
    expect(binding.aesKeyOverride, isA<Uint8List>());
    expect(binding.aesKeyOverride, hasLength(16));
  });

  test('AlarmAccountRegistry reads receiver port from onyx_settings', () async {
    final registry = AlarmAccountRegistry(
      client: _buildSupabaseClient((request) async {
        if (request.url.path.endsWith('/onyx_settings')) {
          return http.Response(
            '[{"value_text":"6500"}]',
            200,
            request: request,
          );
        }
        return http.Response('[]', 200, request: request);
      }),
    );

    final port = await registry.readReceiverPort();

    expect(port, 6500);
  });

  test('AlarmAccountRegistry falls back to the default port', () async {
    final registry = AlarmAccountRegistry(
      client: _buildSupabaseClient(
        (_) async => http.Response('[]', 200),
      ),
    );

    final port = await registry.readReceiverPort();

    expect(port, AlarmAccountRegistry.defaultPort);
  });

  test('AlarmAccountRegistry decodes the global AES key from env', () {
    final key = AlarmAccountRegistry.readGlobalAesKey(const {
      'ONYX_ALARM_AES_KEY': '00112233445566778899AABBCCDDEEFF',
    });

    expect(key, isNotNull);
    expect(key, hasLength(16));
  });
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
