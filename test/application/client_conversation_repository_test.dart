import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

void main() {
  group('SharedPrefsClientConversationRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and restores messages and acknowledgements', () async {
      final persistence = await DispatchPersistenceService.create();
      final repository = SharedPrefsClientConversationRepository(persistence);
      final messages = [
        ClientAppMessage(
          author: 'Resident',
          body: 'Community has been informed.',
          occurredAt: DateTime.utc(2026, 3, 4, 12, 0),
          roomKey: 'Residents',
          viewerRole: 'resident',
          incidentStatusLabel: 'Advisory',
        ),
      ];
      final acknowledgements = [
        ClientAppAcknowledgement(
          messageKey: 'system:notify-1',
          channel: ClientAppAcknowledgementChannel.resident,
          acknowledgedBy: 'Resident',
          acknowledgedAt: DateTime.utc(2026, 3, 4, 12, 1),
        ),
      ];
      final pushQueue = [
        ClientAppPushDeliveryItem(
          messageKey: 'system:notify-1',
          title: 'Dispatch created',
          body: 'Response team activated.',
          occurredAt: DateTime.utc(2026, 3, 4, 12, 2),
          targetChannel: ClientAppAcknowledgementChannel.client,
          priority: true,
          status: ClientPushDeliveryStatus.queued,
        ),
      ];

      await repository.saveMessages(messages);
      await repository.saveAcknowledgements(acknowledgements);
      await repository.savePushQueue(pushQueue);

      final restoredMessages = await repository.readMessages();
      final restoredAcknowledgements = await repository.readAcknowledgements();
      final restoredPushQueue = await repository.readPushQueue();

      expect(
        restoredMessages.map((entry) => entry.toJson()).toList(),
        messages.map((entry) => entry.toJson()).toList(),
      );
      expect(
        restoredAcknowledgements.map((entry) => entry.toJson()).toList(),
        acknowledgements.map((entry) => entry.toJson()).toList(),
      );
      expect(
        restoredPushQueue.map((entry) => entry.toJson()).toList(),
        pushQueue.map((entry) => entry.toJson()).toList(),
      );
    });
  });

  group('FallbackClientConversationRepository', () {
    test('reads from fallback when primary fails', () async {
      final fallback = _FakeClientConversationRepository(
        messages: [
          ClientAppMessage(
            author: 'Client',
            body: 'Fallback message',
            occurredAt: DateTime.utc(2026, 3, 4, 12, 30),
          ),
        ],
      );
      final repository = FallbackClientConversationRepository(
        primary: _FakeClientConversationRepository(throwOnRead: true),
        fallback: fallback,
      );

      final restored = await repository.readMessages();

      expect(restored, hasLength(1));
      expect(restored.single.body, 'Fallback message');
    });

    test('mirrors writes into fallback when primary fails', () async {
      final fallback = _FakeClientConversationRepository();
      final repository = FallbackClientConversationRepository(
        primary: _FakeClientConversationRepository(throwOnWrite: true),
        fallback: fallback,
      );
      final messages = [
        ClientAppMessage(
          author: 'Control',
          body: 'Persist locally',
          occurredAt: DateTime.utc(2026, 3, 4, 12, 45),
        ),
      ];

      await repository.saveMessages(messages);

      expect(fallback.messages.single.body, 'Persist locally');
    });

    test('reads push sync state from fallback when primary fails', () async {
      final fallback = _FakeClientConversationRepository()
        ..storedPushSyncState = ClientPushSyncState(
          statusLabel: 'failed',
          lastSyncedAtUtc: DateTime.utc(2026, 3, 5, 13, 10),
          failureReason: 'network unavailable',
          retryCount: 3,
          history: [
            ClientPushSyncAttempt(
              occurredAt: DateTime.utc(2026, 3, 5, 13, 10),
              status: 'failed',
              failureReason: 'network unavailable',
              queueSize: 4,
            ),
          ],
          backendProbeStatusLabel: 'failed',
          backendProbeLastRunAtUtc: DateTime.utc(2026, 3, 5, 13, 10),
          backendProbeFailureReason: 'network unavailable',
          backendProbeHistory: [
            ClientBackendProbeAttempt(
              occurredAt: DateTime.utc(2026, 3, 5, 13, 10),
              status: 'failed',
              failureReason: 'network unavailable',
            ),
          ],
        );
      final repository = FallbackClientConversationRepository(
        primary: _FakeClientConversationRepository(throwOnRead: true),
        fallback: fallback,
      );

      final restored = await repository.readPushSyncState();

      expect(restored.statusLabel, 'failed');
      expect(restored.retryCount, 3);
      expect(restored.history, hasLength(1));
      expect(restored.history.single.queueSize, 4);
    });

    test(
      'mirrors push sync state writes into fallback when primary fails',
      () async {
        final fallback = _FakeClientConversationRepository();
        final repository = FallbackClientConversationRepository(
          primary: _FakeClientConversationRepository(throwOnWrite: true),
          fallback: fallback,
        );
        final state = ClientPushSyncState(
          statusLabel: 'ok',
          lastSyncedAtUtc: DateTime.utc(2026, 3, 5, 13, 11),
          retryCount: 0,
          history: [
            ClientPushSyncAttempt(
              occurredAt: DateTime.utc(2026, 3, 5, 13, 11),
              status: 'ok',
              queueSize: 0,
            ),
          ],
          backendProbeStatusLabel: 'ok',
          backendProbeLastRunAtUtc: DateTime.utc(2026, 3, 5, 13, 11),
          backendProbeFailureReason: null,
          backendProbeHistory: [
            ClientBackendProbeAttempt(
              occurredAt: DateTime.utc(2026, 3, 5, 13, 11),
              status: 'ok',
            ),
          ],
        );

        await repository.savePushSyncState(state);

        expect(fallback.storedPushSyncState.statusLabel, 'ok');
        expect(fallback.storedPushSyncState.history, hasLength(1));
        expect(fallback.storedPushSyncState.history.single.status, 'ok');
      },
    );
  });
}

class _FakeClientConversationRepository
    implements ClientConversationRepository {
  final bool throwOnRead;
  final bool throwOnWrite;
  List<ClientAppMessage> messages;
  List<ClientAppAcknowledgement> storedAcknowledgements;
  List<ClientAppPushDeliveryItem> storedPushQueue;
  ClientPushSyncState storedPushSyncState;

  _FakeClientConversationRepository({
    this.throwOnRead = false,
    this.throwOnWrite = false,
    this.messages = const [],
  }) : storedAcknowledgements = const [],
       storedPushQueue = const [],
       storedPushSyncState = const ClientPushSyncState.idle();

  @override
  Future<List<ClientAppMessage>> readMessages() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    return messages;
  }

  @override
  Future<void> saveMessages(List<ClientAppMessage> messages) async {
    if (throwOnWrite) {
      throw StateError('write failed');
    }
    this.messages = List<ClientAppMessage>.from(messages);
  }

  @override
  Future<List<ClientAppAcknowledgement>> readAcknowledgements() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    return storedAcknowledgements;
  }

  @override
  Future<void> saveAcknowledgements(
    List<ClientAppAcknowledgement> acknowledgements,
  ) async {
    if (throwOnWrite) {
      throw StateError('write failed');
    }
    storedAcknowledgements = List<ClientAppAcknowledgement>.from(
      acknowledgements,
    );
  }

  @override
  Future<List<ClientAppPushDeliveryItem>> readPushQueue() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    return storedPushQueue;
  }

  @override
  Future<void> savePushQueue(List<ClientAppPushDeliveryItem> pushQueue) async {
    if (throwOnWrite) {
      throw StateError('write failed');
    }
    storedPushQueue = List<ClientAppPushDeliveryItem>.from(pushQueue);
  }

  @override
  Future<ClientPushSyncState> readPushSyncState() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    return storedPushSyncState;
  }

  @override
  Future<void> savePushSyncState(ClientPushSyncState state) async {
    if (throwOnWrite) {
      throw StateError('write failed');
    }
    storedPushSyncState = state;
  }
}
