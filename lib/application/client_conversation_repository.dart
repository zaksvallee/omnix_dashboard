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
    try {
      final messages = await primary.readMessages();
      if (messages.isNotEmpty) {
        await fallback.saveMessages(messages);
        return messages;
      }
    } catch (_) {
      // Fall through to the local cache.
    }
    return fallback.readMessages();
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
    try {
      final acknowledgements = await primary.readAcknowledgements();
      if (acknowledgements.isNotEmpty) {
        await fallback.saveAcknowledgements(acknowledgements);
        return acknowledgements;
      }
    } catch (_) {
      // Fall through to the local cache.
    }
    return fallback.readAcknowledgements();
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
    try {
      final pushQueue = await primary.readPushQueue();
      if (pushQueue.isNotEmpty) {
        await fallback.savePushQueue(pushQueue);
        return pushQueue;
      }
    } catch (_) {
      // Fall through to the local cache.
    }
    return fallback.readPushQueue();
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
    try {
      final state = await primary.readPushSyncState();
      await fallback.savePushSyncState(state);
      return state;
    } catch (_) {
      return fallback.readPushSyncState();
    }
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
    await client
        .from('client_conversation_messages')
        .delete()
        .eq('client_id', clientId)
        .eq('site_id', siteId);
    if (messages.isEmpty) return;
    try {
      await client
          .from('client_conversation_messages')
          .insert(_messageRows(messages, includeSourceProvider: true));
    } catch (_) {
      await client
          .from('client_conversation_messages')
          .insert(_messageRows(messages, includeSourceProvider: false));
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
    await client
        .from('client_conversation_acknowledgements')
        .delete()
        .eq('client_id', clientId)
        .eq('site_id', siteId);
    if (acknowledgements.isEmpty) return;
    await client
        .from('client_conversation_acknowledgements')
        .insert(
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
        );
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
    await client
        .from('client_conversation_push_queue')
        .delete()
        .eq('client_id', clientId)
        .eq('site_id', siteId);
    if (pushQueue.isEmpty) return;
    try {
      await client
          .from('client_conversation_push_queue')
          .insert(_pushQueueRows(pushQueue, includeDeliveryProvider: true));
    } catch (_) {
      await client
          .from('client_conversation_push_queue')
          .insert(_pushQueueRows(pushQueue, includeDeliveryProvider: false));
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
