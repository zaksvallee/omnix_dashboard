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

class ClientTelegramEndpointRecord {
  final String endpointId;
  final String displayLabel;
  final String chatId;
  final int? threadId;
  final String? siteId;

  const ClientTelegramEndpointRecord({
    required this.endpointId,
    required this.displayLabel,
    required this.chatId,
    this.threadId,
    this.siteId,
  });
}

class ClientTelegramScopeTarget {
  final String clientId;
  final String siteId;

  const ClientTelegramScopeTarget({
    required this.clientId,
    required this.siteId,
  });
}

List<ClientTelegramEndpointTarget> selectTelegramTargetsForLane({
  required Iterable<ClientTelegramEndpointRecord> records,
  required bool partnerTargets,
  required bool Function(String displayLabel) isPartnerLabel,
}) {
  final laneRecords = selectTelegramRecordsForLaneAndScope(
    records: records,
    partnerTargets: partnerTargets,
    isPartnerLabel: isPartnerLabel,
  );
  final dedupe = <String>{};
  final targets = <ClientTelegramEndpointTarget>[];
  for (final record in laneRecords) {
    final dedupeKey = '${record.chatId}:${record.threadId ?? ''}';
    if (!dedupe.add(dedupeKey)) {
      continue;
    }
    targets.add(
      ClientTelegramEndpointTarget(
        endpointId: record.endpointId,
        displayLabel: record.displayLabel,
        chatId: record.chatId,
        threadId: record.threadId,
        siteId: record.siteId,
      ),
    );
  }
  return targets;
}

List<ClientTelegramEndpointRecord> selectTelegramRecordsForLaneAndScope({
  required Iterable<ClientTelegramEndpointRecord> records,
  required bool partnerTargets,
  required bool Function(String displayLabel) isPartnerLabel,
}) {
  final scoped = <ClientTelegramEndpointRecord>[];
  final global = <ClientTelegramEndpointRecord>[];
  for (final record in records) {
    final isPartner = isPartnerLabel(record.displayLabel);
    if (isPartner != partnerTargets) {
      continue;
    }
    if ((record.siteId ?? '').trim().isEmpty) {
      global.add(record);
    } else {
      scoped.add(record);
    }
  }
  return scoped.isNotEmpty ? scoped : global;
}

List<ClientTelegramScopeTarget> expandActiveTelegramScopeTargets({
  required List<Map<String, dynamic>> endpointRows,
  required List<Map<String, dynamic>> siteRows,
}) {
  final dedupe = <String>{};
  final scopes = <ClientTelegramScopeTarget>[];
  final globalClientIds = <String>{};
  for (final row in endpointRows) {
    final clientId = (row['client_id'] ?? '').toString().trim();
    final siteId = (row['site_id'] ?? '').toString().trim();
    if (clientId.isEmpty) {
      continue;
    }
    if (siteId.isEmpty) {
      globalClientIds.add(clientId);
      continue;
    }
    final key = '$clientId|$siteId';
    if (!dedupe.add(key)) {
      continue;
    }
    scopes.add(ClientTelegramScopeTarget(clientId: clientId, siteId: siteId));
  }
  for (final row in siteRows) {
    final clientId = (row['client_id'] ?? '').toString().trim();
    final siteId = (row['site_id'] ?? '').toString().trim();
    if (clientId.isEmpty || siteId.isEmpty || !globalClientIds.contains(clientId)) {
      continue;
    }
    final key = '$clientId|$siteId';
    if (!dedupe.add(key)) {
      continue;
    }
    scopes.add(ClientTelegramScopeTarget(clientId: clientId, siteId: siteId));
  }
  return scopes;
}

List<Map<String, dynamic>> selectActiveTelegramEndpointRowsForScope({
  required List<Map<String, dynamic>> rows,
  required String? siteId,
}) {
  final normalizedSiteId = (siteId ?? '').trim();
  final globalRows = <Map<String, dynamic>>[];
  final scopedRows = <Map<String, dynamic>>[];
  for (final row in rows) {
    final rowSiteId = (row['site_id'] ?? '').toString().trim();
    if (normalizedSiteId.isEmpty) {
      if (rowSiteId.isEmpty) {
        globalRows.add(row);
      }
      continue;
    }
    if (rowSiteId == normalizedSiteId) {
      scopedRows.add(row);
      continue;
    }
    if (rowSiteId.isEmpty) {
      globalRows.add(row);
    }
  }
  return scopedRows.isNotEmpty ? scopedRows : globalRows;
}

List<Map<String, dynamic>> selectManagedTelegramEndpointRowsForScope({
  required List<Map<String, dynamic>> rows,
  required String? siteId,
}) {
  final normalizedSiteId = (siteId ?? '').trim();
  return rows.where((row) {
    final rowSiteId = (row['site_id'] ?? '').toString().trim();
    if (normalizedSiteId.isEmpty) {
      return rowSiteId.isEmpty;
    }
    return rowSiteId.isEmpty || rowSiteId == normalizedSiteId;
  }).toList(growable: false);
}

List<String> selectActiveContactPhonesForScope({
  required List<Map<String, dynamic>> rows,
  required String? siteId,
}) {
  final normalizedSiteId = (siteId ?? '').trim();
  final scopedPrimaryPhones = <String>{};
  final scopedFallbackPhones = <String>{};
  final globalPrimaryPhones = <String>{};
  final globalFallbackPhones = <String>{};
  for (final row in rows) {
    final rowSiteId = (row['site_id'] ?? '').toString().trim();
    final isGlobalRow = rowSiteId.isEmpty;
    final isScopedRow = normalizedSiteId.isNotEmpty && rowSiteId == normalizedSiteId;
    if (normalizedSiteId.isEmpty) {
      if (!isGlobalRow) {
        continue;
      }
    } else if (!isGlobalRow && !isScopedRow) {
      continue;
    }
    final role = (row['role'] ?? '').toString().trim().toLowerCase();
    if (role == 'response_partner') {
      continue;
    }
    final phone = (row['phone'] ?? '').toString().trim();
    if (phone.isEmpty) {
      continue;
    }
    final isPrimary = row['is_primary'] == true;
    if (isGlobalRow) {
      globalFallbackPhones.add(phone);
      if (isPrimary) {
        globalPrimaryPhones.add(phone);
      }
      continue;
    }
    scopedFallbackPhones.add(phone);
    if (isPrimary) {
      scopedPrimaryPhones.add(phone);
    }
  }
  if (scopedPrimaryPhones.isNotEmpty) {
    return scopedPrimaryPhones.toList(growable: false);
  }
  if (scopedFallbackPhones.isNotEmpty) {
    return scopedFallbackPhones.toList(growable: false);
  }
  if (globalPrimaryPhones.isNotEmpty) {
    return globalPrimaryPhones.toList(growable: false);
  }
  return globalFallbackPhones.toList(growable: false);
}

List<String> primaryContactIdsToDemoteForUpsert({
  required List<Map<String, dynamic>> rows,
  required String? siteId,
  required String contactRole,
  required String keepContactId,
}) {
  final normalizedSiteId = (siteId ?? '').trim();
  final normalizedRole = contactRole.trim().toLowerCase();
  final normalizedKeepContactId = keepContactId.trim();
  return rows
      .where((row) {
        final rowId = (row['id'] ?? '').toString().trim();
        if (rowId.isEmpty || rowId == normalizedKeepContactId) {
          return false;
        }
        final rowSiteId = (row['site_id'] ?? '').toString().trim();
        if (rowSiteId != normalizedSiteId) {
          return false;
        }
        final rowRole = (row['role'] ?? '').toString().trim().toLowerCase();
        if (rowRole != normalizedRole) {
          return false;
        }
        return row['is_primary'] == true;
      })
      .map((row) => (row['id'] ?? '').toString().trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
}

List<Map<String, String>> staleSubscriptionPairsToDeactivateForUpsert({
  required List<Map<String, dynamic>> subscriptionRows,
  required List<Map<String, dynamic>> contactRows,
  required List<Map<String, dynamic>> endpointRows,
  required String? siteId,
  required String provider,
  required String contactRole,
  required String keepContactId,
  required String keepEndpointId,
}) {
  final normalizedSiteId = (siteId ?? '').trim();
  final normalizedProvider = provider.trim().toLowerCase();
  final normalizedRole = contactRole.trim().toLowerCase();
  final normalizedKeepContactId = keepContactId.trim();
  final normalizedKeepEndpointId = keepEndpointId.trim();
  final contactRoleById = <String, String>{};
  for (final row in contactRows) {
    final contactId = (row['id'] ?? '').toString().trim();
    if (contactId.isEmpty) {
      continue;
    }
    contactRoleById[contactId] = (row['role'] ?? '').toString().trim().toLowerCase();
  }
  final endpointProviderById = <String, String>{};
  for (final row in endpointRows) {
    final endpointId = (row['id'] ?? '').toString().trim();
    if (endpointId.isEmpty) {
      continue;
    }
    endpointProviderById[endpointId] = (row['provider'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }
  final stalePairs = <Map<String, String>>[];
  final seenPairs = <String>{};
  for (final row in subscriptionRows) {
    final contactId = (row['contact_id'] ?? '').toString().trim();
    final endpointId = (row['endpoint_id'] ?? '').toString().trim();
    if (contactId.isEmpty || endpointId.isEmpty) {
      continue;
    }
    if (contactId == normalizedKeepContactId &&
        endpointId == normalizedKeepEndpointId) {
      continue;
    }
    final rowSiteId = (row['site_id'] ?? '').toString().trim();
    if (rowSiteId != normalizedSiteId) {
      continue;
    }
    if (row['is_active'] == false) {
      continue;
    }
    final rowRole = contactRoleById[contactId] ?? '';
    if (rowRole != normalizedRole) {
      continue;
    }
    final rowProvider = endpointProviderById[endpointId] ?? '';
    if (rowProvider != normalizedProvider) {
      continue;
    }
    final pairKey = '$contactId|$endpointId';
    if (!seenPairs.add(pairKey)) {
      continue;
    }
    stalePairs.add(<String, String>{
      'contact_id': contactId,
      'endpoint_id': endpointId,
    });
  }
  return stalePairs;
}

List<Map<String, String>> activeSubscriptionPairsForEndpointIds({
  required List<Map<String, dynamic>> subscriptionRows,
  required Iterable<String> endpointIds,
}) {
  final normalizedEndpointIds = endpointIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final activePairs = <Map<String, String>>[];
  final seenPairs = <String>{};
  for (final row in subscriptionRows) {
    if (row['is_active'] == false) {
      continue;
    }
    final contactId = (row['contact_id'] ?? '').toString().trim();
    final endpointId = (row['endpoint_id'] ?? '').toString().trim();
    if (contactId.isEmpty ||
        endpointId.isEmpty ||
        !normalizedEndpointIds.contains(endpointId)) {
      continue;
    }
    final pairKey = '$contactId|$endpointId';
    if (!seenPairs.add(pairKey)) {
      continue;
    }
    activePairs.add(<String, String>{
      'contact_id': contactId,
      'endpoint_id': endpointId,
    });
  }
  return activePairs;
}

Map<String, dynamic>? findExistingEndpointRowForUpsert({
  required List<Map<String, dynamic>> rows,
  required String? siteId,
  required String provider,
  String? telegramChatId,
  String? telegramThreadId,
}) {
  final normalizedSiteId = (siteId ?? '').trim();
  final normalizedProvider = provider.trim().toLowerCase();
  final normalizedChatId = (telegramChatId ?? '').trim();
  final normalizedThreadId = (telegramThreadId ?? '').trim();
  return rows.cast<Map<String, dynamic>?>().firstWhere((row) {
    if (row == null) {
      return false;
    }
    final rowSiteId = (row['site_id'] ?? '').toString().trim();
    if (rowSiteId != normalizedSiteId) {
      return false;
    }
    final rowProvider = (row['provider'] ?? '').toString().trim().toLowerCase();
    if (rowProvider != normalizedProvider) {
      return false;
    }
    if (normalizedProvider == 'telegram' && normalizedChatId.isNotEmpty) {
      final rowChatId = (row['telegram_chat_id'] ?? '').toString().trim();
      final rowThreadId = (row['telegram_thread_id'] ?? '').toString().trim();
      return rowChatId == normalizedChatId &&
          rowThreadId == normalizedThreadId;
    }
    return true;
  }, orElse: () => null);
}

String? resolvedContactConsentAtForUpsert({
  required Map<String, dynamic>? existingRow,
  required bool contactConsentConfirmed,
  required DateTime nowUtc,
}) {
  if (contactConsentConfirmed) {
    return nowUtc.toIso8601String();
  }
  final existingConsentAt = (existingRow?['consent_at'] ?? '').toString().trim();
  return existingConsentAt.isEmpty ? null : existingConsentAt;
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
    final contactRowsRaw = await client
        .from('client_contacts')
        .select('id, role')
        .eq('client_id', clientId)
        .order('created_at');
    final endpointRowsRaw = await client
        .from('client_messaging_endpoints')
        .select('id, provider')
        .eq('client_id', clientId)
        .order('created_at');
    final subscriptionRowsRaw = await client
        .from('client_contact_endpoint_subscriptions')
        .select('contact_id, endpoint_id, site_id, is_active')
        .eq('client_id', clientId)
        .order('created_at');
    final stalePairs = staleSubscriptionPairsToDeactivateForUpsert(
      subscriptionRows: List<Map<String, dynamic>>.from(subscriptionRowsRaw),
      contactRows: List<Map<String, dynamic>>.from(contactRowsRaw),
      endpointRows: List<Map<String, dynamic>>.from(endpointRowsRaw),
      siteId: normalizedSiteId,
      provider: provider,
      contactRole: setup.contactRole.trim().isEmpty
          ? 'sovereign_contact'
          : setup.contactRole.trim(),
      keepContactId: contactId,
      keepEndpointId: endpointId,
    );
    for (final pair in stalePairs) {
      await client
          .from('client_contact_endpoint_subscriptions')
          .update({'is_active': false})
          .eq('client_id', clientId)
          .eq('contact_id', pair['contact_id']!)
          .eq('endpoint_id', pair['endpoint_id']!);
    }
  }

  Future<List<ClientTelegramEndpointTarget>> readActiveTelegramTargets({
    required String clientId,
    String? siteId,
  }) async {
    final records = await readActiveTelegramEndpointRecords(
      clientId: clientId,
      siteId: siteId,
    );
    final dedupe = <String>{};
    final targets = <ClientTelegramEndpointTarget>[];
    for (final record in records) {
      final dedupeKey = '${record.chatId}:${record.threadId ?? ''}';
      if (!dedupe.add(dedupeKey)) {
        continue;
      }
      targets.add(
        ClientTelegramEndpointTarget(
          endpointId: record.endpointId,
          displayLabel: record.displayLabel,
          chatId: record.chatId,
          threadId: record.threadId,
          siteId: record.siteId,
        ),
      );
    }
    return targets;
  }

  Future<List<ClientTelegramEndpointRecord>> readActiveTelegramEndpointRecords({
    required String clientId,
    String? siteId,
  }) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return const <ClientTelegramEndpointRecord>[];
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
    final filtered = selectActiveTelegramEndpointRowsForScope(
      rows: rows,
      siteId: normalizedSiteId,
    );
    return _telegramEndpointRecordsFromRows(filtered);
  }

  Future<List<ClientTelegramEndpointRecord>> readManagedTelegramEndpointRecords({
    required String clientId,
    String? siteId,
  }) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return const <ClientTelegramEndpointRecord>[];
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
    final filtered = selectManagedTelegramEndpointRowsForScope(
      rows: rows,
      siteId: normalizedSiteId,
    );
    return _telegramEndpointRecordsFromRows(filtered);
  }

  List<ClientTelegramEndpointRecord> _telegramEndpointRecordsFromRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final targets = <ClientTelegramEndpointRecord>[];
    for (final row in rows) {
      final endpointId = (row['id'] ?? '').toString().trim();
      final chatId = (row['telegram_chat_id'] ?? '').toString().trim();
      if (endpointId.isEmpty || chatId.isEmpty) {
        continue;
      }
      final threadRaw = (row['telegram_thread_id'] ?? '').toString().trim();
      final threadId = threadRaw.isEmpty ? null : int.tryParse(threadRaw);
      targets.add(
        ClientTelegramEndpointRecord(
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

  Future<List<ClientTelegramScopeTarget>> readActiveTelegramScopes() async {
    final endpointRowsRaw = await client
        .from('client_messaging_endpoints')
        .select('client_id, site_id')
        .eq('provider', 'telegram')
        .eq('is_active', true)
        .order('created_at');
    final endpointRows = List<Map<String, dynamic>>.from(endpointRowsRaw);
    final globalClientIds = endpointRows
        .map((row) => (row['client_id'] ?? '').toString().trim())
        .where((clientId) => clientId.isNotEmpty)
        .where((clientId) {
          return endpointRows.any((row) {
            final rowClientId = (row['client_id'] ?? '').toString().trim();
            final rowSiteId = (row['site_id'] ?? '').toString().trim();
            return rowClientId == clientId && rowSiteId.isEmpty;
          });
        })
        .toSet()
        .toList(growable: false);
    var siteRows = <Map<String, dynamic>>[];
    if (globalClientIds.isNotEmpty) {
      final siteRowsRaw = await client
          .from('sites')
          .select('client_id, site_id')
          .inFilter('client_id', globalClientIds)
          .eq('is_active', true)
          .order('created_at');
      siteRows = List<Map<String, dynamic>>.from(siteRowsRaw);
    }
    return expandActiveTelegramScopeTargets(
      endpointRows: endpointRows,
      siteRows: siteRows,
    );
  }

  Future<List<String>> readActiveContactPhones({
    required String clientId,
    String? siteId,
  }) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return const <String>[];
    }
    final normalizedSiteId = siteId?.trim() ?? '';
    final rowsRaw = await client
        .from('client_contacts')
        .select('site_id, phone, role, is_primary')
        .eq('client_id', normalizedClientId)
        .eq('is_active', true)
        .order('created_at');
    final rows = List<Map<String, dynamic>>.from(rowsRaw);
    return selectActiveContactPhonesForScope(
      rows: rows,
      siteId: normalizedSiteId,
    );
  }

  Future<int> deactivateTelegramEndpointsByChat({
    required String clientId,
    required String siteId,
    required String chatId,
    int? threadId,
    bool includeGlobalScope = true,
    String lastDeliveryStatus = 'disabled',
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
          final inScope =
              rowSiteId == normalizedSiteId ||
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
    return deactivateEndpointIds(
      clientId: normalizedClientId,
      endpointIds: endpointIds,
      lastDeliveryStatus: lastDeliveryStatus,
    );
  }

  Future<int> deactivateTelegramEndpointsForScope({
    required String clientId,
    required String siteId,
    bool includeGlobalScope = true,
    String lastDeliveryStatus = 'disabled',
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
    return deactivateEndpointIds(
      clientId: normalizedClientId,
      endpointIds: endpointIds,
      lastDeliveryStatus: lastDeliveryStatus,
    );
  }

  Future<int> deactivateEndpointIds({
    required String clientId,
    required List<String> endpointIds,
    String lastDeliveryStatus = 'disabled',
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedEndpointIds = endpointIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedClientId.isEmpty || normalizedEndpointIds.isEmpty) {
      return 0;
    }
    for (final endpointId in normalizedEndpointIds) {
      await client
          .from('client_messaging_endpoints')
          .update({
            'is_active': false,
            'last_delivery_status': lastDeliveryStatus,
          })
          .eq('id', endpointId)
          .eq('client_id', normalizedClientId);
    }
    await _deactivateActiveSubscriptionsForEndpoints(
      clientId: normalizedClientId,
      endpointIds: normalizedEndpointIds,
    );
    return normalizedEndpointIds.length;
  }

  Future<void> _deactivateActiveSubscriptionsForEndpoints({
    required String clientId,
    required List<String> endpointIds,
  }) async {
    if (endpointIds.isEmpty) {
      return;
    }
    final subscriptionRowsRaw = await client
        .from('client_contact_endpoint_subscriptions')
        .select('contact_id, endpoint_id, is_active')
        .eq('client_id', clientId)
        .order('created_at');
    final activePairs = activeSubscriptionPairsForEndpointIds(
      subscriptionRows: List<Map<String, dynamic>>.from(subscriptionRowsRaw),
      endpointIds: endpointIds,
    );
    for (final pair in activePairs) {
      await client
          .from('client_contact_endpoint_subscriptions')
          .update({'is_active': false})
          .eq('client_id', clientId)
          .eq('contact_id', pair['contact_id']!)
          .eq('endpoint_id', pair['endpoint_id']!);
    }
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
        .select('id, site_id, full_name, role, consent_at, is_primary')
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
    final nowUtc = DateTime.now().toUtc();
    final payload = <String, Object?>{
      'client_id': clientId,
      'site_id': siteId,
      'full_name': contactName,
      'role': contactRole,
      'phone': _nullIfBlank(contactPhone),
      'email': _nullIfBlank(contactEmail),
      'is_primary': true,
      'consent_at': resolvedContactConsentAtForUpsert(
        existingRow: existing,
        contactConsentConfirmed: contactConsentConfirmed,
        nowUtc: nowUtc,
      ),
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
      final demoteIds = primaryContactIdsToDemoteForUpsert(
        rows: rows,
        siteId: siteId,
        contactRole: contactRole,
        keepContactId: existingId,
      );
      for (final contactId in demoteIds) {
        await client
            .from('client_contacts')
            .update({'is_primary': false})
            .eq('id', contactId)
            .eq('client_id', clientId);
      }
      return existingId;
    }
    final inserted = await client
        .from('client_contacts')
        .insert(payload)
        .select('id')
        .single();
    final insertedId = (inserted['id'] ?? '').toString();
    final demoteIds = primaryContactIdsToDemoteForUpsert(
      rows: rows,
      siteId: siteId,
      contactRole: contactRole,
      keepContactId: insertedId,
    );
    for (final contactId in demoteIds) {
      await client
          .from('client_contacts')
          .update({'is_primary': false})
          .eq('id', contactId)
          .eq('client_id', clientId);
    }
    return insertedId;
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
        .select('id, site_id, provider, telegram_chat_id, telegram_thread_id')
        .eq('client_id', clientId)
        .eq('provider', provider)
        .order('created_at');
    final rows = List<Map<String, dynamic>>.from(rowsRaw);
    final existing = findExistingEndpointRowForUpsert(
      rows: rows,
      siteId: siteId,
      provider: provider,
      telegramChatId: telegramChatId,
      telegramThreadId: telegramThreadId,
    );
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
