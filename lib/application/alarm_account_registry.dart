import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'runtime_config.dart';

class AlarmAccountBinding {
  final String accountNumber;
  final String clientId;
  final String siteId;
  final String? aesKeyOverrideHex;

  const AlarmAccountBinding({
    required this.accountNumber,
    required this.clientId,
    required this.siteId,
    this.aesKeyOverrideHex,
  });

  Uint8List? get aesKeyOverride {
    final raw = aesKeyOverrideHex?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return AlarmAccountRegistry.tryDecodeHexKey(raw);
  }

  factory AlarmAccountBinding.fromJson(Map<String, Object?> json) {
    return AlarmAccountBinding(
      accountNumber: (json['account_number'] ?? '').toString().trim(),
      clientId: (json['client_id'] ?? '').toString().trim(),
      siteId: (json['site_id'] ?? '').toString().trim(),
      aesKeyOverrideHex: (json['aes_key_override'] ?? '').toString().trim().isEmpty
          ? null
          : (json['aes_key_override'] ?? '').toString().trim(),
    );
  }
}

class AlarmAccountRegistry {
  static const defaultPort = 5072;
  static const _portSettingKey = 'sia_dc09_port';

  final SupabaseClient client;

  const AlarmAccountRegistry({required this.client});

  Future<AlarmAccountBinding?> resolve(String accountNumber) async {
    final normalized = accountNumber.trim();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final row = await client
          .from('alarm_accounts')
          .select('account_number, client_id, site_id, aes_key_override')
          .eq('account_number', normalized)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      final rowMap = Map<String, Object?>.from(row);
      final binding = AlarmAccountBinding.fromJson(
        rowMap.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (binding.accountNumber.isEmpty ||
          binding.clientId.isEmpty ||
          binding.siteId.isEmpty) {
        return null;
      }
      return binding;
    } catch (_) {
      return null;
    }
  }

  Future<int> readReceiverPort() async {
    try {
      final row = await client
          .from('onyx_settings')
          .select('value_text')
          .eq('key', _portSettingKey)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return defaultPort;
      }
      final rowMap = Map<String, Object?>.from(row);
      final parsed = int.tryParse(
        (rowMap['value_text'] ?? '').toString().trim(),
      );
      return parsed ?? defaultPort;
    } catch (_) {
      return defaultPort;
    }
  }

  Uint8List resolveAesKey({
    required Uint8List globalAesKey,
    AlarmAccountBinding? binding,
  }) {
    return binding?.aesKeyOverride ?? globalAesKey;
  }

  static Uint8List? readGlobalAesKey(Map<String, String> env) {
    final raw = OnyxRuntimeConfig.usableSecret(
      env['ONYX_ALARM_AES_KEY'] ?? '',
    );
    if (raw.isEmpty) {
      return null;
    }
    return tryDecodeHexKey(raw);
  }

  static Uint8List? tryDecodeHexKey(String raw) {
    final normalized = raw.trim();
    if (normalized.length != 32) {
      return null;
    }
    final bytes = <int>[];
    for (var index = 0; index < normalized.length; index += 2) {
      final value = int.tryParse(normalized.substring(index, index + 2), radix: 16);
      if (value == null) {
        return null;
      }
      bytes.add(value);
    }
    return Uint8List.fromList(bytes);
  }
}
