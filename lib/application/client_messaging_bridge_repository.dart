import 'package:supabase_flutter/supabase_flutter.dart';

class ClientMessagingOnboardingSetup {
  final String clientId;
  final String? siteId;
  final String contactName;
  final String contactRole;
  final String? contactPhone;
  final String? contactEmail;
  final bool contactConsentConfirmed;
  final String provider;
  final String endpointLabel;
  final String? telegramChatId;
  final String? telegramThreadId;
  final List<String> incidentPriorities;
  final List<String> incidentTypes;

  const ClientMessagingOnboardingSetup({
    required this.clientId,
    this.siteId,
    required this.contactName,
    this.contactRole = 'sovereign_contact',
    this.contactPhone,
    this.contactEmail,
    this.contactConsentConfirmed = false,
    required this.provider,
    required this.endpointLabel,
    this.telegramChatId,
    this.telegramThreadId,
    this.incidentPriorities = const <String>['p1', 'p2', 'p3', 'p4'],
    this.incidentTypes = const <String>[],
  });
}

class ClientTelegramEndpointTarget {
  final String endpointId;
  final String displayLabel;
  final String chatId;
  final int? threadId;
  final String? siteId;

  const ClientTelegramEndpointTarget({
    required this.endpointId,
    required this.displayLabel,
    required this.chatId,
    this.threadId,
    this.siteId,
  });
}

class SupabaseClientMessagingBridgeRepository {
  final SupabaseClient client;

  const SupabaseClientMessagingBridgeRepository(this.client);

  Future<void> upsertOnboardingSetup(
    ClientMessagingOnboardingSetup setup,
  ) async {
    final clientId = setup.clientId.trim();
    if (clientId.isEmpty) return;
    final scopeSiteId = setup.siteId?.trim();
    final normalizedSiteId = (scopeSiteId == null || scopeSiteId.isEmpty)
        ? null
        : scopeSiteId;
    final contactName = setup.contactName.trim();
    if (contactName.isEmpty) return;
    final provider = setup.provider.trim().toLowerCase();
    if (provider != 'telegram' && provider != 'in_app') return;
    final endpointLabel = setup.endpointLabel.trim().isEmpty
        ? (provider == 'telegram' ? 'Primary Telegram Bridge' : 'In-App Lane')
        : setup.endpointLabel.trim();
    final telegramChatId = setup.telegramChatId?.trim();
    final telegramThreadId = setup.telegramThreadId?.trim();

    final contactId = await _upsertContact(
      clientId: clientId,
      siteId: normalizedSiteId,
      contactName: contactName,
      contactRole: setup.contactRole.trim().isEmpty
          ? 'sovereign_contact'
          : setup.contactRole.trim(),
      contactPhone: setup.contactPhone?.trim(),
      contactEmail: setup.contactEmail?.trim(),
      contactConsentConfirmed: setup.contactConsentConfirmed,
    );
    final endpointId = await _upsertEndpoint(
      clientId: clientId,
      siteId: normalizedSiteId,
      provider: provider,
      endpointLabel: endpointLabel,
      telegramChatId: telegramChatId,
      telegramThreadId: telegramThreadId,
    );
    await client.from('client_contact_endpoint_subscriptions').upsert({
      'client_id': clientId,
      'site_id': normalizedSiteId,
      'contact_id': contactId,
      'endpoint_id': endpointId,
      'incident_priorities': setup.incidentPriorities,
      'incident_types': setup.incidentTypes,
      'quiet_hours': <String, Object?>{},
      'is_active': true,
    }, onConflict: 'contact_id,endpoint_id');
  }

  Future<List<ClientTelegramEndpointTarget>> readActiveTelegramTargets({
    required String clientId,
    String? siteId,
  }) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return const <ClientTelegramEndpointTarget>[];
    }
    final normalizedSiteId = siteId?.trim() ?? '';
    final rowsRaw = await client
        .from('client_messaging_endpoints')
        .select(
          'id, site_id, display_label, telegram_chat_id, telegram_thread_id',
        )
        .eq('client_id', normalizedClientId)
        .eq('provider', 'telegram')
        .eq('is_active', true)
        .order('created_at');
    final rows = List<Map<String, dynamic>>.from(rowsRaw);
    final filtered = rows.where((row) {
      final rowSiteId = (row['site_id'] ?? '').toString().trim();
      if (normalizedSiteId.isEmpty) {
        return rowSiteId.isEmpty;
      }
      return rowSiteId.isEmpty || rowSiteId == normalizedSiteId;
    });
    final dedupe = <String>{};
    final targets = <ClientTelegramEndpointTarget>[];
    for (final row in filtered) {
      final endpointId = (row['id'] ?? '').toString().trim();
      final chatId = (row['telegram_chat_id'] ?? '').toString().trim();
      if (endpointId.isEmpty || chatId.isEmpty) {
        continue;
      }
      final threadRaw = (row['telegram_thread_id'] ?? '').toString().trim();
      final threadId = threadRaw.isEmpty ? null : int.tryParse(threadRaw);
      final dedupeKey = '$chatId:${threadId ?? ''}';
      if (!dedupe.add(dedupeKey)) {
        continue;
      }
      targets.add(
        ClientTelegramEndpointTarget(
          endpointId: endpointId,
          displayLabel: (row['display_label'] ?? '').toString().trim().isEmpty
              ? 'Telegram'
              : (row['display_label'] ?? '').toString().trim(),
          chatId: chatId,
          threadId: threadId,
          siteId: (row['site_id'] ?? '').toString().trim().isEmpty
              ? null
              : (row['site_id'] ?? '').toString().trim(),
        ),
      );
    }
    return targets;
  }

  Future<int> deactivateTelegramEndpointsByChat({
    required String clientId,
    required String siteId,
    required String chatId,
    int? threadId,
    bool includeGlobalScope = true,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedChatId = chatId.trim();
    if (normalizedClientId.isEmpty ||
        normalizedSiteId.isEmpty ||
        normalizedChatId.isEmpty) {
      return 0;
    }
    final rowsRaw = await client
        .from('client_messaging_endpoints')
        .select('id, site_id, telegram_thread_id')
        .eq('client_id', normalizedClientId)
        .eq('provider', 'telegram')
        .eq('telegram_chat_id', normalizedChatId)
        .eq('is_active', true)
        .order('created_at');
    final rows = List<Map<String, dynamic>>.from(rowsRaw);
    final endpointIds = rows
        .where((row) {
          final rowSiteId = (row['site_id'] ?? '').toString().trim();
          final inScope = rowSiteId == normalizedSiteId ||
              (includeGlobalScope && rowSiteId.isEmpty);
          if (!inScope) return false;
          final rowThreadRaw = (row['telegram_thread_id'] ?? '')
              .toString()
              .trim();
          final rowThreadId = rowThreadRaw.isEmpty
              ? null
              : int.tryParse(rowThreadRaw);
          return rowThreadId == threadId;
        })
        .map((row) => (row['id'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (endpointIds.isEmpty) {
      return 0;
    }
    for (final endpointId in endpointIds) {
      await client
          .from('client_messaging_endpoints')
          .update({
            'is_active': false,
            'last_delivery_status': 'disabled',
          })
          .eq('id', endpointId)
          .eq('client_id', normalizedClientId);
    }
    return endpointIds.length;
  }

  Future<int> deactivateTelegramEndpointsForScope({
    required String clientId,
    required String siteId,
    bool includeGlobalScope = true,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
      return 0;
    }
    final rowsRaw = await client
        .from('client_messaging_endpoints')
        .select('id, site_id')
        .eq('client_id', normalizedClientId)
        .eq('provider', 'telegram')
        .eq('is_active', true)
        .order('created_at');
    final rows = List<Map<String, dynamic>>.from(rowsRaw);
    final endpointIds = rows
        .where((row) {
          final rowSiteId = (row['site_id'] ?? '').toString().trim();
          return rowSiteId == normalizedSiteId ||
              (includeGlobalScope && rowSiteId.isEmpty);
        })
        .map((row) => (row['id'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (endpointIds.isEmpty) {
      return 0;
    }
    for (final endpointId in endpointIds) {
      await client
          .from('client_messaging_endpoints')
          .update({
            'is_active': false,
            'last_delivery_status': 'disabled',
          })
          .eq('id', endpointId)
          .eq('client_id', normalizedClientId);
    }
    return endpointIds.length;
  }

  Future<String> _upsertContact({
    required String clientId,
    required String? siteId,
    required String contactName,
    required String contactRole,
    String? contactPhone,
    String? contactEmail,
    required bool contactConsentConfirmed,
  }) async {
    final rowsRaw = await client
        .from('client_contacts')
        .select('id, site_id, full_name, role')
        .eq('client_id', clientId)
        .order('created_at');
    final rows = List<Map<String, dynamic>>.from(rowsRaw);
    final existing = rows.cast<Map<String, dynamic>?>().firstWhere((row) {
      if (row == null) return false;
      final rowSite = (row['site_id'] ?? '').toString().trim();
      final sameScope = (siteId ?? '') == rowSite;
      if (!sameScope) return false;
      final sameName =
          (row['full_name'] ?? '').toString().trim().toLowerCase() ==
          contactName.toLowerCase();
      final sameRole =
          (row['role'] ?? '').toString().trim().toLowerCase() ==
          contactRole.toLowerCase();
      return sameName && sameRole;
    }, orElse: () => null);
    final payload = <String, Object?>{
      'client_id': clientId,
      'site_id': siteId,
      'full_name': contactName,
      'role': contactRole,
      'phone': _nullIfBlank(contactPhone),
      'email': _nullIfBlank(contactEmail),
      'is_primary': true,
      'consent_at': contactConsentConfirmed
          ? DateTime.now().toUtc().toIso8601String()
          : null,
      'is_active': true,
      'metadata': <String, Object?>{'onboarding_source': 'admin_stepper'},
    };
    final existingId = (existing?['id'] ?? '').toString().trim();
    if (existingId.isNotEmpty) {
      await client
          .from('client_contacts')
          .update(payload)
          .eq('id', existingId)
          .eq('client_id', clientId);
      return existingId;
    }
    final inserted = await client
        .from('client_contacts')
        .insert(payload)
        .select('id')
        .single();
    return (inserted['id'] ?? '').toString();
  }

  Future<String> _upsertEndpoint({
    required String clientId,
    required String? siteId,
    required String provider,
    required String endpointLabel,
    String? telegramChatId,
    String? telegramThreadId,
  }) async {
    final rowsRaw = await client
        .from('client_messaging_endpoints')
        .select('id, site_id, provider, telegram_chat_id')
        .eq('client_id', clientId)
        .eq('provider', provider)
        .order('created_at');
    final rows = List<Map<String, dynamic>>.from(rowsRaw);
    final existing = rows.cast<Map<String, dynamic>?>().firstWhere((row) {
      if (row == null) return false;
      final rowSite = (row['site_id'] ?? '').toString().trim();
      if ((siteId ?? '') != rowSite) return false;
      if (provider == 'telegram' && (telegramChatId ?? '').isNotEmpty) {
        return (row['telegram_chat_id'] ?? '').toString().trim() ==
            telegramChatId;
      }
      return true;
    }, orElse: () => null);
    final payload = <String, Object?>{
      'client_id': clientId,
      'site_id': siteId,
      'provider': provider,
      'display_label': endpointLabel,
      'telegram_chat_id': provider == 'telegram'
          ? _nullIfBlank(telegramChatId)
          : null,
      'telegram_thread_id': provider == 'telegram'
          ? _nullIfBlank(telegramThreadId)
          : null,
      'verified_at': DateTime.now().toUtc().toIso8601String(),
      'is_active': true,
      'last_delivery_status': 'configured',
      'last_error': null,
      'metadata': <String, Object?>{'onboarding_source': 'admin_stepper'},
    };
    final existingId = (existing?['id'] ?? '').toString().trim();
    if (existingId.isNotEmpty) {
      await client
          .from('client_messaging_endpoints')
          .update(payload)
          .eq('id', existingId)
          .eq('client_id', clientId);
      return existingId;
    }
    final inserted = await client
        .from('client_messaging_endpoints')
        .insert(payload)
        .select('id')
        .single();
    return (inserted['id'] ?? '').toString();
  }

  static String? _nullIfBlank(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
