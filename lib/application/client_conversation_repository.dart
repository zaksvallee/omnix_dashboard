import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/client_app_page.dart';
import 'dispatch_persistence_service.dart';

abstract class ClientConversationRepository {
  Future<List<ClientAppMessage>> readMessages();
  Future<void> saveMessages(List<ClientAppMessage> messages);

  Future<List<ClientAppAcknowledgement>> readAcknowledgements();
  Future<void> saveAcknowledgements(
    List<ClientAppAcknowledgement> acknowledgements,
  );

  Future<List<ClientAppPushDeliveryItem>> readPushQueue();
  Future<void> savePushQueue(List<ClientAppPushDeliveryItem> pushQueue);

  Future<ClientPushSyncState> readPushSyncState();
  Future<void> savePushSyncState(ClientPushSyncState state);
}

ClientConversationRepository? buildScopedClientConversationRepository({
  required DispatchPersistenceService persistence,
  required String clientId,
  required String siteId,
  required bool supabaseReady,
  SupabaseClient? supabaseClient,
}) {
  final normalizedClientId = clientId.trim();
  final normalizedSiteId = siteId.trim();
  if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
    return null;
  }
  final localRepository = ScopedSharedPrefsClientConversationRepository(
    persistence: persistence,
    clientId: normalizedClientId,
    siteId: normalizedSiteId,
  );
  if (!supabaseReady || supabaseClient == null) {
    return localRepository;
  }
  return FallbackClientConversationRepository(
    primary: SupabaseClientConversationRepository(
      client: supabaseClient,
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    ),
    fallback: localRepository,
  );
}

List<ClientAppMessage> _mergeConversationMessages({
  required List<ClientAppMessage> fallbackMessages,
  required List<ClientAppMessage> primaryMessages,
}) {
  final seenKeys = <String>{};
  final merged = <ClientAppMessage>[];
  for (final message in <ClientAppMessage>[
    ...fallbackMessages,
    ...primaryMessages,
  ]) {
    final key = [
      message.author,
      message.body,
      message.roomKey,
      message.viewerRole,
      message.incidentStatusLabel,
      message.messageSource,
      message.messageProvider,
      message.occurredAt.toUtc().toIso8601String(),
    ].join('|');
    if (seenKeys.add(key)) {
      merged.add(message);
    }
  }
  merged.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
  return merged;
}

List<ClientAppAcknowledgement> _mergeAcknowledgements({
  required List<ClientAppAcknowledgement> fallbackAcknowledgements,
  required List<ClientAppAcknowledgement> primaryAcknowledgements,
}) {
  final mergedByKey = <String, ClientAppAcknowledgement>{};
  for (final acknowledgement in fallbackAcknowledgements) {
    mergedByKey[acknowledgement.messageKey] = acknowledgement;
  }
  for (final acknowledgement in primaryAcknowledgements) {
    mergedByKey.putIfAbsent(acknowledgement.messageKey, () => acknowledgement);
  }
  final merged = mergedByKey.values.toList(
    growable: false,
  )..sort((left, right) => right.acknowledgedAt.compareTo(left.acknowledgedAt));
  return merged;
}

List<ClientAppPushDeliveryItem> _mergePushQueue({
  required List<ClientAppPushDeliveryItem> fallbackPushQueue,
  required List<ClientAppPushDeliveryItem> primaryPushQueue,
}) {
  final mergedByKey = <String, ClientAppPushDeliveryItem>{};
  for (final item in fallbackPushQueue) {
    mergedByKey[item.messageKey] = item;
  }
  for (final item in primaryPushQueue) {
    mergedByKey.putIfAbsent(item.messageKey, () => item);
  }
  final merged = mergedByKey.values.toList(growable: false)
    ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
  return merged;
}

bool _hasMeaningfulPushSyncState(ClientPushSyncState state) {
  return state.statusLabel.trim().toLowerCase() != 'idle' ||
      state.lastSyncedAtUtc != null ||
      (state.failureReason ?? '').trim().isNotEmpty ||
      state.retryCount > 0 ||
      state.history.isNotEmpty ||
      state.telegramDeliveredMessageKeys.isNotEmpty ||
      state.backendProbeStatusLabel.trim().toLowerCase() != 'idle' ||
      state.backendProbeLastRunAtUtc != null ||
      (state.backendProbeFailureReason ?? '').trim().isNotEmpty ||
      state.backendProbeHistory.isNotEmpty;
}

String _conversationMessageRemoteSyncKey(ClientAppMessage message) {
  return [
    message.author,
    message.body,
    message.roomKey,
    message.viewerRole,
    message.incidentStatusLabel,
    message.occurredAt.toUtc().toIso8601String(),
  ].join('|');
}

List<ClientAppMessage> missingConversationMessagesForRemoteSync({
  required List<ClientAppMessage> desiredMessages,
  required List<ClientAppMessage> existingMessages,
}) {
  final existingKeys = existingMessages
      .map(_conversationMessageRemoteSyncKey)
      .toSet();
  return desiredMessages
      .where(
        (message) =>
            !existingKeys.contains(_conversationMessageRemoteSyncKey(message)),
      )
      .toList(growable: false);
}

String _conversationAcknowledgementRemoteSyncKey(
  ClientAppAcknowledgement acknowledgement,
) {
  return '${acknowledgement.messageKey}|${acknowledgement.channel.name}';
}

List<ClientAppAcknowledgement> staleConversationAcknowledgementsForRemoteSync({
  required List<ClientAppAcknowledgement> desiredAcknowledgements,
  required List<ClientAppAcknowledgement> existingAcknowledgements,
}) {
  final desiredKeys = desiredAcknowledgements
      .map(_conversationAcknowledgementRemoteSyncKey)
      .toSet();
  return existingAcknowledgements
      .where(
        (acknowledgement) => !desiredKeys.contains(
          _conversationAcknowledgementRemoteSyncKey(acknowledgement),
        ),
      )
      .toList(growable: false);
}

String _conversationPushQueueRemoteSyncKey(ClientAppPushDeliveryItem item) {
  return item.messageKey;
}

List<ClientAppPushDeliveryItem> staleConversationPushQueueForRemoteSync({
  required List<ClientAppPushDeliveryItem> desiredPushQueue,
  required List<ClientAppPushDeliveryItem> existingPushQueue,
}) {
  final desiredKeys = desiredPushQueue
      .map(_conversationPushQueueRemoteSyncKey)
      .toSet();
  return existingPushQueue
      .where(
        (item) =>
            !desiredKeys.contains(_conversationPushQueueRemoteSyncKey(item)),
      )
      .toList(growable: false);
}

class SharedPrefsClientConversationRepository
    implements ClientConversationRepository {
  final DispatchPersistenceService persistence;

  const SharedPrefsClientConversationRepository(this.persistence);

  @override
  Future<List<ClientAppMessage>> readMessages() {
    return persistence.readClientAppMessages();
  }

  @override
  Future<void> saveMessages(List<ClientAppMessage> messages) {
    return persistence.saveClientAppMessages(messages);
  }

  @override
  Future<List<ClientAppAcknowledgement>> readAcknowledgements() {
    return persistence.readClientAppAcknowledgements();
  }

  @override
  Future<void> saveAcknowledgements(
    List<ClientAppAcknowledgement> acknowledgements,
  ) {
    return persistence.saveClientAppAcknowledgements(acknowledgements);
  }

  @override
  Future<List<ClientAppPushDeliveryItem>> readPushQueue() {
    return persistence.readClientAppPushQueue();
  }

  @override
  Future<void> savePushQueue(List<ClientAppPushDeliveryItem> pushQueue) {
    return persistence.saveClientAppPushQueue(pushQueue);
  }

  @override
  Future<ClientPushSyncState> readPushSyncState() {
    return persistence.readClientAppPushSyncState();
  }

  @override
  Future<void> savePushSyncState(ClientPushSyncState state) {
    return persistence.saveClientAppPushSyncState(state);
  }
}

class ScopedSharedPrefsClientConversationRepository
    implements ClientConversationRepository {
  final DispatchPersistenceService persistence;
  final String clientId;
  final String siteId;

  const ScopedSharedPrefsClientConversationRepository({
    required this.persistence,
    required this.clientId,
    required this.siteId,
  });

  @override
  Future<List<ClientAppMessage>> readMessages() {
    return persistence.readScopedClientAppMessages(
      clientId: clientId,
      siteId: siteId,
    );
  }

  @override
  Future<void> saveMessages(List<ClientAppMessage> messages) {
    return persistence.saveScopedClientAppMessages(
      messages,
      clientId: clientId,
      siteId: siteId,
    );
  }

  @override
  Future<List<ClientAppAcknowledgement>> readAcknowledgements() {
    return persistence.readScopedClientAppAcknowledgements(
      clientId: clientId,
      siteId: siteId,
    );
  }

  @override
  Future<void> saveAcknowledgements(
    List<ClientAppAcknowledgement> acknowledgements,
  ) {
    return persistence.saveScopedClientAppAcknowledgements(
      acknowledgements,
      clientId: clientId,
      siteId: siteId,
    );
  }

  @override
  Future<List<ClientAppPushDeliveryItem>> readPushQueue() {
    return persistence.readScopedClientAppPushQueue(
      clientId: clientId,
      siteId: siteId,
    );
  }

  @override
  Future<void> savePushQueue(List<ClientAppPushDeliveryItem> pushQueue) {
    return persistence.saveScopedClientAppPushQueue(
      pushQueue,
      clientId: clientId,
      siteId: siteId,
    );
  }

  @override
  Future<ClientPushSyncState> readPushSyncState() {
    return persistence.readScopedClientAppPushSyncState(
      clientId: clientId,
      siteId: siteId,
    );
  }

  @override
  Future<void> savePushSyncState(ClientPushSyncState state) {
    return persistence.saveScopedClientAppPushSyncState(
      state,
      clientId: clientId,
      siteId: siteId,
    );
  }
}

class FallbackClientConversationRepository
    implements ClientConversationRepository {
  final ClientConversationRepository primary;
  final ClientConversationRepository fallback;

  const FallbackClientConversationRepository({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<List<ClientAppMessage>> readMessages() async {
    final fallbackMessages = await fallback.readMessages();
    try {
      final primaryMessages = await primary.readMessages();
      if (primaryMessages.isNotEmpty) {
        final mergedMessages = _mergeConversationMessages(
          fallbackMessages: fallbackMessages,
          primaryMessages: primaryMessages,
        );
        await fallback.saveMessages(mergedMessages);
        return mergedMessages;
      }
    } catch (_) {
      // Fall through to the local cache.
    }
    return fallbackMessages;
  }

  @override
  Future<void> saveMessages(List<ClientAppMessage> messages) async {
    Object? primaryError;
    try {
      await primary.saveMessages(messages);
    } catch (error) {
      primaryError = error;
    }
    await fallback.saveMessages(messages);
    if (primaryError != null) {
      // Local cache is authoritative when the primary backend is unavailable.
      return;
    }
  }

  @override
  Future<List<ClientAppAcknowledgement>> readAcknowledgements() async {
    final fallbackAcknowledgements = await fallback.readAcknowledgements();
    try {
      final primaryAcknowledgements = await primary.readAcknowledgements();
      if (primaryAcknowledgements.isNotEmpty) {
        final mergedAcknowledgements = _mergeAcknowledgements(
          fallbackAcknowledgements: fallbackAcknowledgements,
          primaryAcknowledgements: primaryAcknowledgements,
        );
        await fallback.saveAcknowledgements(mergedAcknowledgements);
        return mergedAcknowledgements;
      }
    } catch (_) {
      // Fall through to the local cache.
    }
    return fallbackAcknowledgements;
  }

  @override
  Future<void> saveAcknowledgements(
    List<ClientAppAcknowledgement> acknowledgements,
  ) async {
    Object? primaryError;
    try {
      await primary.saveAcknowledgements(acknowledgements);
    } catch (error) {
      primaryError = error;
    }
    await fallback.saveAcknowledgements(acknowledgements);
    if (primaryError != null) {
      return;
    }
  }

  @override
  Future<List<ClientAppPushDeliveryItem>> readPushQueue() async {
    final fallbackPushQueue = await fallback.readPushQueue();
    try {
      final primaryPushQueue = await primary.readPushQueue();
      if (primaryPushQueue.isNotEmpty) {
        final mergedPushQueue = _mergePushQueue(
          fallbackPushQueue: fallbackPushQueue,
          primaryPushQueue: primaryPushQueue,
        );
        await fallback.savePushQueue(mergedPushQueue);
        return mergedPushQueue;
      }
    } catch (_) {
      // Fall through to the local cache.
    }
    return fallbackPushQueue;
  }

  @override
  Future<void> savePushQueue(List<ClientAppPushDeliveryItem> pushQueue) async {
    Object? primaryError;
    try {
      await primary.savePushQueue(pushQueue);
    } catch (error) {
      primaryError = error;
    }
    await fallback.savePushQueue(pushQueue);
    if (primaryError != null) {
      return;
    }
  }

  @override
  Future<ClientPushSyncState> readPushSyncState() async {
    final fallbackState = await fallback.readPushSyncState();
    try {
      final primaryState = await primary.readPushSyncState();
      if (_hasMeaningfulPushSyncState(primaryState) ||
          !_hasMeaningfulPushSyncState(fallbackState)) {
        await fallback.savePushSyncState(primaryState);
        return primaryState;
      }
    } catch (_) {
      // Fall through to the local cache.
    }
    return fallbackState;
  }

  @override
  Future<void> savePushSyncState(ClientPushSyncState state) async {
    Object? primaryError;
    try {
      await primary.savePushSyncState(state);
    } catch (error) {
      primaryError = error;
    }
    await fallback.savePushSyncState(state);
    if (primaryError != null) {
      return;
    }
  }
}

class SupabaseClientConversationRepository
    implements ClientConversationRepository {
  final SupabaseClient client;
  final String clientId;
  final String siteId;

  const SupabaseClientConversationRepository({
    required this.client,
    required this.clientId,
    required this.siteId,
  });

  @override
  Future<List<ClientAppMessage>> readMessages() async {
    try {
      final response = await client
          .from('client_conversation_messages')
          .select(
            'author, body, room_key, viewer_role, incident_status_label, message_source, message_provider, occurred_at',
          )
          .eq('client_id', clientId)
          .eq('site_id', siteId)
          .order('occurred_at', ascending: false);
      return _mapMessageRows(response);
    } catch (_) {
      final response = await client
          .from('client_conversation_messages')
          .select(
            'author, body, room_key, viewer_role, incident_status_label, occurred_at',
          )
          .eq('client_id', clientId)
          .eq('site_id', siteId)
          .order('occurred_at', ascending: false);
      return _mapMessageRows(response);
    }
  }

  @override
  Future<void> saveMessages(List<ClientAppMessage> messages) async {
    if (messages.isEmpty) {
      return;
    }
    final existingMessages = await readMessages();
    final missingMessages = missingConversationMessagesForRemoteSync(
      desiredMessages: messages,
      existingMessages: existingMessages,
    );
    if (missingMessages.isEmpty) {
      return;
    }
    try {
      await client
          .from('client_conversation_messages')
          .insert(_messageRows(missingMessages, includeSourceProvider: true));
    } catch (_) {
      await client
          .from('client_conversation_messages')
          .insert(_messageRows(missingMessages, includeSourceProvider: false));
    }
  }

  List<ClientAppMessage> _mapMessageRows(dynamic response) {
    return response
        .whereType<Map>()
        .map(
          (row) => ClientAppMessage(
            author: row['author']?.toString() ?? '',
            body: row['body']?.toString() ?? '',
            roomKey: row['room_key']?.toString() ?? 'Residents',
            viewerRole: row['viewer_role']?.toString() ?? 'client',
            incidentStatusLabel:
                row['incident_status_label']?.toString() ?? 'Update',
            messageSource: row['message_source']?.toString() ?? 'in_app',
            messageProvider: row['message_provider']?.toString() ?? 'in_app',
            occurredAt:
                DateTime.tryParse(
                  row['occurred_at']?.toString() ?? '',
                )?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        )
        .where((message) => message.body.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, Object?>> _messageRows(
    List<ClientAppMessage> messages, {
    required bool includeSourceProvider,
  }) {
    return messages
        .map((message) {
          final row = <String, Object?>{
            'client_id': clientId,
            'site_id': siteId,
            'author': message.author,
            'body': message.body,
            'room_key': message.roomKey,
            'viewer_role': message.viewerRole,
            'incident_status_label': message.incidentStatusLabel,
            'occurred_at': message.occurredAt.toUtc().toIso8601String(),
          };
          if (includeSourceProvider) {
            row['message_source'] = message.messageSource;
            row['message_provider'] = message.messageProvider;
          }
          return row;
        })
        .toList(growable: false);
  }

  @override
  Future<List<ClientAppAcknowledgement>> readAcknowledgements() async {
    final response = await client
        .from('client_conversation_acknowledgements')
        .select('message_key, channel, acknowledged_by, acknowledged_at')
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .order('acknowledged_at', ascending: false);
    return response
        .whereType<Map>()
        .map(
          (row) => ClientAppAcknowledgement(
            messageKey: row['message_key']?.toString() ?? '',
            channel: ClientAppAcknowledgementChannel.values.firstWhere(
              (value) => value.name == row['channel']?.toString(),
              orElse: () => ClientAppAcknowledgementChannel.client,
            ),
            acknowledgedBy: row['acknowledged_by']?.toString() ?? '',
            acknowledgedAt:
                DateTime.tryParse(
                  row['acknowledged_at']?.toString() ?? '',
                )?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        )
        .where(
          (acknowledgement) => acknowledgement.messageKey.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveAcknowledgements(
    List<ClientAppAcknowledgement> acknowledgements,
  ) async {
    List<ClientAppAcknowledgement> existingAcknowledgements =
        const <ClientAppAcknowledgement>[];
    try {
      existingAcknowledgements = await readAcknowledgements();
    } catch (_) {
      existingAcknowledgements = const <ClientAppAcknowledgement>[];
    }
    if (acknowledgements.isEmpty) {
      await client
          .from('client_conversation_acknowledgements')
          .delete()
          .eq('client_id', clientId)
          .eq('site_id', siteId);
      return;
    }
    await client
        .from('client_conversation_acknowledgements')
        .upsert(
          acknowledgements
              .map(
                (acknowledgement) => {
                  'client_id': clientId,
                  'site_id': siteId,
                  'message_key': acknowledgement.messageKey,
                  'channel': acknowledgement.channel.name,
                  'acknowledged_by': acknowledgement.acknowledgedBy,
                  'acknowledged_at': acknowledgement.acknowledgedAt
                      .toUtc()
                      .toIso8601String(),
                },
              )
              .toList(growable: false),
          onConflict: 'client_id,site_id,message_key,channel',
        );
    final staleAcknowledgements =
        staleConversationAcknowledgementsForRemoteSync(
          desiredAcknowledgements: acknowledgements,
          existingAcknowledgements: existingAcknowledgements,
        );
    for (final acknowledgement in staleAcknowledgements) {
      await client
          .from('client_conversation_acknowledgements')
          .delete()
          .eq('client_id', clientId)
          .eq('site_id', siteId)
          .eq('message_key', acknowledgement.messageKey)
          .eq('channel', acknowledgement.channel.name);
    }
  }

  @override
  Future<List<ClientAppPushDeliveryItem>> readPushQueue() async {
    try {
      final response = await client
          .from('client_conversation_push_queue')
          .select(
            'message_key, title, body, occurred_at, target_channel, delivery_provider, priority, status',
          )
          .eq('client_id', clientId)
          .eq('site_id', siteId)
          .order('occurred_at', ascending: false);
      return _mapPushQueueRows(response);
    } catch (_) {
      final response = await client
          .from('client_conversation_push_queue')
          .select(
            'message_key, title, body, occurred_at, target_channel, priority, status',
          )
          .eq('client_id', clientId)
          .eq('site_id', siteId)
          .order('occurred_at', ascending: false);
      return _mapPushQueueRows(response);
    }
  }

  @override
  Future<void> savePushQueue(List<ClientAppPushDeliveryItem> pushQueue) async {
    List<ClientAppPushDeliveryItem> existingPushQueue =
        const <ClientAppPushDeliveryItem>[];
    try {
      existingPushQueue = await readPushQueue();
    } catch (_) {
      existingPushQueue = const <ClientAppPushDeliveryItem>[];
    }
    if (pushQueue.isEmpty) {
      await client
          .from('client_conversation_push_queue')
          .delete()
          .eq('client_id', clientId)
          .eq('site_id', siteId);
      return;
    }
    try {
      await client
          .from('client_conversation_push_queue')
          .upsert(
            _pushQueueRows(pushQueue, includeDeliveryProvider: true),
            onConflict: 'client_id,site_id,message_key',
          );
    } catch (_) {
      await client
          .from('client_conversation_push_queue')
          .upsert(
            _pushQueueRows(pushQueue, includeDeliveryProvider: false),
            onConflict: 'client_id,site_id,message_key',
          );
    }
    final stalePushQueue = staleConversationPushQueueForRemoteSync(
      desiredPushQueue: pushQueue,
      existingPushQueue: existingPushQueue,
    );
    for (final item in stalePushQueue) {
      await client
          .from('client_conversation_push_queue')
          .delete()
          .eq('client_id', clientId)
          .eq('site_id', siteId)
          .eq('message_key', item.messageKey);
    }
  }

  List<ClientAppPushDeliveryItem> _mapPushQueueRows(dynamic response) {
    return response
        .whereType<Map>()
        .map(
          (row) => ClientAppPushDeliveryItem(
            messageKey: row['message_key']?.toString() ?? '',
            title: row['title']?.toString() ?? '',
            body: row['body']?.toString() ?? '',
            occurredAt:
                DateTime.tryParse(
                  row['occurred_at']?.toString() ?? '',
                )?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            targetChannel: ClientAppAcknowledgementChannel.values.firstWhere(
              (value) => value.name == row['target_channel']?.toString(),
              orElse: () => ClientAppAcknowledgementChannel.client,
            ),
            deliveryProvider: ClientPushDeliveryProviderParser.fromCode(
              row['delivery_provider']?.toString() ?? 'in_app',
            ),
            priority: row['priority'] == true,
            status: ClientPushDeliveryStatus.values.firstWhere(
              (value) => value.name == row['status']?.toString(),
              orElse: () => ClientPushDeliveryStatus.queued,
            ),
          ),
        )
        .where((item) => item.messageKey.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, Object?>> _pushQueueRows(
    List<ClientAppPushDeliveryItem> pushQueue, {
    required bool includeDeliveryProvider,
  }) {
    return pushQueue
        .map((item) {
          final row = <String, Object?>{
            'client_id': clientId,
            'site_id': siteId,
            'message_key': item.messageKey,
            'title': item.title,
            'body': item.body,
            'occurred_at': item.occurredAt.toUtc().toIso8601String(),
            'target_channel': item.targetChannel.name,
            'priority': item.priority,
            'status': item.status.name,
          };
          if (includeDeliveryProvider) {
            row['delivery_provider'] = item.deliveryProvider.code;
          }
          return row;
        })
        .toList(growable: false);
  }

  @override
  Future<ClientPushSyncState> readPushSyncState() async {
    final response = await client
        .from('client_conversation_push_sync_state')
        .select(
          'status_label, last_synced_at, failure_reason, retry_count, history, probe_status_label, probe_last_run_at, probe_failure_reason, probe_history',
        )
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .maybeSingle();
    if (response == null) {
      return const ClientPushSyncState.idle();
    }
    return ClientPushSyncState.fromJson({
      'status': response['status_label'],
      'lastSyncedAtUtc': response['last_synced_at'],
      'failureReason': response['failure_reason'],
      'retryCount': response['retry_count'],
      'history': response['history'],
      'backendProbeStatus': response['probe_status_label'],
      'backendProbeLastRunAtUtc': response['probe_last_run_at'],
      'backendProbeFailureReason': response['probe_failure_reason'],
      'backendProbeHistory': response['probe_history'],
    });
  }

  @override
  Future<void> savePushSyncState(ClientPushSyncState state) async {
    await client.from('client_conversation_push_sync_state').upsert({
      'client_id': clientId,
      'site_id': siteId,
      'status_label': state.statusLabel,
      'last_synced_at': state.lastSyncedAtUtc?.toIso8601String(),
      'failure_reason': state.failureReason,
      'retry_count': state.retryCount,
      'history': state.history
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'probe_status_label': state.backendProbeStatusLabel,
      'probe_last_run_at': state.backendProbeLastRunAtUtc?.toIso8601String(),
      'probe_failure_reason': state.backendProbeFailureReason,
      'probe_history': state.backendProbeHistory
          .map((entry) => entry.toJson())
          .toList(growable: false),
    }, onConflict: 'client_id,site_id');
  }
}
