import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

DateTime _adminRouteStateOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 18, hour, minute);

Future<void> saveTelegramAdminRuntimeState(Map<String, Object?> state) async {
  final persistence = await DispatchPersistenceService.create();
  await persistence.saveTelegramAdminRuntimeState(state);
}

Future<ScopedSharedPrefsClientConversationRepository>
waterfallScopedConversation() async {
  final persistence = await DispatchPersistenceService.create();
  return ScopedSharedPrefsClientConversationRepository(
    persistence: persistence,
    clientId: 'CLIENT-DEMO',
    siteId: 'WTF-MAIN',
  );
}

Future<SharedPrefsClientConversationRepository>
defaultValleeConversation() async {
  final persistence = await DispatchPersistenceService.create();
  return SharedPrefsClientConversationRepository(persistence);
}

Future<void> seedDefaultValleeQueuedDelivery({
  required String messageKey,
  required DateTime occurredAtUtc,
  String title = 'Delivery check',
  String body = 'This is a queued client delivery check.',
}) async {
  final conversation = await defaultValleeConversation();
  await conversation.savePushQueue(<ClientAppPushDeliveryItem>[
    ClientAppPushDeliveryItem(
      messageKey: messageKey,
      title: title,
      body: body,
      occurredAt: occurredAtUtc,
      clientId: 'CLIENT-DEMO',
      siteId: 'SITE-DEMO',
      targetChannel: ClientAppAcknowledgementChannel.client,
      deliveryProvider: ClientPushDeliveryProvider.inApp,
      priority: true,
      status: ClientPushDeliveryStatus.queued,
    ),
  ]);
}

Future<void> seedWaterfallQueuedDelivery({
  required String messageKey,
  required DateTime occurredAtUtc,
  String title = 'Waterfall delivery check',
  String body = 'Queued client update for the Waterfall lane.',
  ClientPushDeliveryStatus status = ClientPushDeliveryStatus.queued,
  DateTime? acknowledgedAtUtc,
  String acknowledgedBy = 'Client',
}) async {
  final conversation = await waterfallScopedConversation();
  await conversation.savePushQueue(<ClientAppPushDeliveryItem>[
    ClientAppPushDeliveryItem(
      messageKey: messageKey,
      title: title,
      body: body,
      occurredAt: occurredAtUtc,
      clientId: 'CLIENT-DEMO',
      siteId: 'WTF-MAIN',
      targetChannel: ClientAppAcknowledgementChannel.client,
      deliveryProvider: ClientPushDeliveryProvider.inApp,
      priority: true,
      status: status,
    ),
  ]);
  if (acknowledgedAtUtc != null) {
    await conversation.saveAcknowledgements(<ClientAppAcknowledgement>[
      ClientAppAcknowledgement(
        messageKey: messageKey,
        channel: ClientAppAcknowledgementChannel.client,
        acknowledgedBy: acknowledgedBy,
        acknowledgedAt: acknowledgedAtUtc,
      ),
    ]);
  }
}

Future<void> seedWaterfallPushPressure({
  required String messageKey,
  DateTime? occurredAtUtc,
}) async {
  final scopedConversation = await waterfallScopedConversation();
  final queuedAtUtc = occurredAtUtc ?? _adminRouteStateOccurredAtUtc(13, 14);
  const failureReason =
      'Waterfall push sync needs operator review before retry.';
  await scopedConversation.savePushQueue(<ClientAppPushDeliveryItem>[
    ClientAppPushDeliveryItem(
      messageKey: messageKey,
      title: 'Waterfall delivery check',
      body: 'Queued client update for the Waterfall lane.',
      occurredAt: queuedAtUtc,
      clientId: 'CLIENT-DEMO',
      siteId: 'WTF-MAIN',
      targetChannel: ClientAppAcknowledgementChannel.client,
      deliveryProvider: ClientPushDeliveryProvider.inApp,
      priority: true,
      status: ClientPushDeliveryStatus.queued,
    ),
  ]);
  await scopedConversation.savePushSyncState(
    ClientPushSyncState(
      statusLabel: 'failed',
      lastSyncedAtUtc: queuedAtUtc,
      failureReason: failureReason,
      retryCount: 2,
      history: <ClientPushSyncAttempt>[
        ClientPushSyncAttempt(
          occurredAt: queuedAtUtc,
          status: 'failed',
          failureReason: failureReason,
          queueSize: 1,
        ),
      ],
      backendProbeStatusLabel: 'idle',
      backendProbeHistory: const <ClientBackendProbeAttempt>[],
    ),
  );
}

Future<void> seedWaterfallResidentAsk() async {
  final scopedConversation = await waterfallScopedConversation();
  await scopedConversation.saveMessages(<ClientAppMessage>[
    ClientAppMessage(
      author: '@waterfall_resident',
      body:
          'Please confirm whether the Waterfall response team has already arrived.',
      occurredAt: _adminRouteStateOccurredAtUtc(12, 43),
      roomKey: 'Residents',
      viewerRole: ClientAppViewerRole.client.name,
      incidentStatusLabel: 'Update',
      messageSource: 'telegram',
      messageProvider: 'telegram',
    ),
  ]);
}

Future<void> seedWaterfallSmsFallbackPushSync({DateTime? occurredAtUtc}) async {
  final syncedAtUtc = occurredAtUtc ?? _adminRouteStateOccurredAtUtc(13, 23);
  await _saveWaterfallPushSyncState(
    syncedAtUtc: syncedAtUtc,
    statusLabel: 'degraded',
    failureReason:
        'BulkSMS reached 2/2 contacts after telegram target failure.',
    retryCount: 1,
    historyStatus: 'sms-fallback-ok',
  );
}

Future<void> seedWaterfallVoipStagePushSync({DateTime? occurredAtUtc}) async {
  final syncedAtUtc = occurredAtUtc ?? _adminRouteStateOccurredAtUtc(13, 24);
  await _saveWaterfallPushSyncState(
    syncedAtUtc: syncedAtUtc,
    statusLabel: 'degraded',
    failureReason: 'voip:asterisk staged call for Waterfall command desk.',
    retryCount: 0,
    historyStatus: 'voip-staged',
  );
}

Future<void> seedWaterfallTelegramBlockedPushSync() async {
  await seedWaterfallTelegramBlockedPushSyncAt(
    occurredAtUtc: _adminRouteStateOccurredAtUtc(13, 26),
  );
}

Future<void> seedWaterfallTelegramBlockedPushSyncAt({
  required DateTime occurredAtUtc,
}) async {
  await _saveWaterfallPushSyncState(
    syncedAtUtc: occurredAtUtc,
    statusLabel: 'failed',
    failureReason:
        'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
    retryCount: 1,
    historyStatus: 'telegram-blocked',
  );
}

Future<void> seedDefaultValleeVoipStagePushSync({
  DateTime? occurredAtUtc,
}) async {
  final syncedAtUtc = occurredAtUtc ?? _adminRouteStateOccurredAtUtc(12, 55);
  await _saveDefaultValleePushSyncState(
    syncedAtUtc: syncedAtUtc,
    statusLabel: 'degraded',
    failureReason: 'voip:asterisk staged call for Vallee command desk.',
    retryCount: 0,
    history: <ClientPushSyncAttempt>[
      ClientPushSyncAttempt(
        occurredAt: syncedAtUtc,
        status: 'voip-staged',
        failureReason: 'voip:asterisk staged call for Vallee command desk.',
        queueSize: 1,
      ),
    ],
  );
}

Future<void> seedDefaultValleeVoipAndSmsFallbackHistory({
  DateTime? voipOccurredAtUtc,
  DateTime? smsFallbackOccurredAtUtc,
}) async {
  final latestVoipAtUtc =
      voipOccurredAtUtc ?? _adminRouteStateOccurredAtUtc(13, 5);
  final fallbackAtUtc =
      smsFallbackOccurredAtUtc ?? _adminRouteStateOccurredAtUtc(13, 4);
  await _saveDefaultValleePushSyncState(
    syncedAtUtc: latestVoipAtUtc,
    statusLabel: 'degraded',
    failureReason: 'voip:asterisk staged call for Vallee command desk.',
    retryCount: 0,
    history: <ClientPushSyncAttempt>[
      ClientPushSyncAttempt(
        occurredAt: latestVoipAtUtc,
        status: 'voip-staged',
        failureReason: 'voip:asterisk staged call for Vallee command desk.',
        queueSize: 1,
      ),
      ClientPushSyncAttempt(
        occurredAt: fallbackAtUtc,
        status: 'sms-fallback-ok',
        failureReason:
            'BulkSMS reached 2/2 contacts after telegram target failure.',
        queueSize: 2,
      ),
    ],
  );
}

Future<void> seedWaterfallScopedVoipFailurePushSync({
  required DateTime occurredAtUtc,
  int retryCount = 0,
  DateTime? backendProbeOccurredAtUtc,
  String failureReason =
      'VoIP staging is not configured for Thabo Mokoena yet.',
  String backendProbeFailureReason = 'Probe marker readback failed.',
}) async {
  final persistence = await DispatchPersistenceService.create();
  await persistence.saveScopedClientAppPushSyncState(
    ClientPushSyncState(
      statusLabel: 'degraded',
      lastSyncedAtUtc: occurredAtUtc,
      failureReason: failureReason,
      retryCount: retryCount,
      history: <ClientPushSyncAttempt>[
        ClientPushSyncAttempt(
          occurredAt: occurredAtUtc,
          status: 'voip-failed',
          failureReason: failureReason,
          queueSize: 1,
        ),
      ],
      backendProbeStatusLabel: backendProbeOccurredAtUtc == null
          ? 'idle'
          : 'failed',
      backendProbeLastRunAtUtc: backendProbeOccurredAtUtc,
      backendProbeFailureReason: backendProbeOccurredAtUtc == null
          ? null
          : backendProbeFailureReason,
      backendProbeHistory: backendProbeOccurredAtUtc == null
          ? const <ClientBackendProbeAttempt>[]
          : <ClientBackendProbeAttempt>[
              ClientBackendProbeAttempt(
                occurredAt: backendProbeOccurredAtUtc,
                status: 'failed',
                failureReason: backendProbeFailureReason,
              ),
            ],
    ),
    clientId: 'CLIENT-DEMO',
    siteId: 'WTF-MAIN',
  );
}

Future<void> _saveWaterfallPushSyncState({
  required DateTime syncedAtUtc,
  required String statusLabel,
  required String failureReason,
  required int retryCount,
  required String historyStatus,
}) async {
  final scopedConversation = await waterfallScopedConversation();
  await scopedConversation.savePushSyncState(
    ClientPushSyncState(
      statusLabel: statusLabel,
      lastSyncedAtUtc: syncedAtUtc,
      failureReason: failureReason,
      retryCount: retryCount,
      history: <ClientPushSyncAttempt>[
        ClientPushSyncAttempt(
          occurredAt: syncedAtUtc,
          status: historyStatus,
          failureReason: failureReason,
          queueSize: 1,
        ),
      ],
      backendProbeStatusLabel: 'idle',
      backendProbeHistory: const <ClientBackendProbeAttempt>[],
    ),
  );
}

Future<void> _saveDefaultValleePushSyncState({
  required DateTime syncedAtUtc,
  required String statusLabel,
  required String failureReason,
  required int retryCount,
  required List<ClientPushSyncAttempt> history,
}) async {
  final conversation = await defaultValleeConversation();
  await conversation.savePushSyncState(
    ClientPushSyncState(
      statusLabel: statusLabel,
      lastSyncedAtUtc: syncedAtUtc,
      failureReason: failureReason,
      retryCount: retryCount,
      history: history,
      backendProbeStatusLabel: 'idle',
      backendProbeHistory: const <ClientBackendProbeAttempt>[],
    ),
  );
}

Map<String, Object?> learnedApprovalRuntimeState(
  List<Map<String, Object?>> entries, {
  String scopeKey = 'CLIENT-DEMO|SITE-DEMO',
}) {
  return {
    'ai_approved_rewrite_examples_by_scope': {scopeKey: entries},
  };
}

Map<String, Object?> learnedApprovalEntry({
  required String text,
  int? approvalCount,
  String? operatorTag,
}) {
  final entry = <String, Object?>{'text': text};
  if (approvalCount != null) {
    entry['approval_count'] = approvalCount;
  }
  if (operatorTag != null) {
    entry['operator_tag'] = operatorTag;
  }
  return entry;
}

Future<void> saveLearnedApprovalStyles(
  List<Map<String, Object?>> entries, {
  String scopeKey = 'CLIENT-DEMO|SITE-DEMO',
}) async {
  await saveTelegramAdminRuntimeState(
    learnedApprovalRuntimeState(entries, scopeKey: scopeKey),
  );
}

Map<String, Object?> pinnedLaneVoiceRuntimeState({
  required String profile,
  String scopeKey = 'CLIENT-DEMO|SITE-DEMO',
}) {
  return {
    'ai_client_profile_overrides': {scopeKey: profile},
  };
}

Future<void> savePinnedLaneVoice({
  required String profile,
  String scopeKey = 'CLIENT-DEMO|SITE-DEMO',
}) async {
  await saveTelegramAdminRuntimeState(
    pinnedLaneVoiceRuntimeState(profile: profile, scopeKey: scopeKey),
  );
}

Map<String, Object?> legacyLearnedApprovalRuntimeState(
  List<String> entries, {
  String scopeKey = 'CLIENT-DEMO|SITE-DEMO',
}) {
  return {
    'ai_approved_rewrite_examples_by_scope': {scopeKey: entries},
  };
}

Future<void> saveLegacyLearnedApprovalStyles(
  List<String> entries, {
  String scopeKey = 'CLIENT-DEMO|SITE-DEMO',
}) async {
  await saveTelegramAdminRuntimeState(
    legacyLearnedApprovalRuntimeState(entries, scopeKey: scopeKey),
  );
}

Future<void> saveLiveOperationsQueueHintState({
  required bool seen,
  List<String> legacyLearnedStyles = const <String>[],
}) async {
  await saveTelegramAdminRuntimeState({
    'live_operations_queue_hint_seen': seen,
    if (legacyLearnedStyles.isNotEmpty)
      ...legacyLearnedApprovalRuntimeState(legacyLearnedStyles),
  });
}

Map<String, Object?> pendingDraftRuntimeState(
  List<Map<String, Object?>> entries,
) {
  return {'ai_pending_drafts': entries};
}

Map<String, Object?> telegramPendingDraftEntry({
  required int inboundUpdateId,
  required int messageThreadId,
  required String clientId,
  required String siteId,
  required String sourceText,
  required String originalDraftText,
  required String draftText,
  required DateTime createdAtUtc,
  String chatId = '123456',
  String audience = 'client',
  String providerLabel = 'openai:gpt-4.1-mini',
  bool usedLearnedApprovalStyle = false,
}) {
  return {
    'inbound_update_id': inboundUpdateId,
    'chat_id': chatId,
    'message_thread_id': messageThreadId,
    'audience': audience,
    'client_id': clientId,
    'site_id': siteId,
    'source_text': sourceText,
    'original_draft_text': originalDraftText,
    'draft_text': draftText,
    'provider_label': providerLabel,
    'used_learned_approval_style': usedLearnedApprovalStyle,
    'created_at_utc': createdAtUtc.toIso8601String(),
  };
}

Future<void> savePendingTelegramDrafts(
  List<Map<String, Object?>> entries,
) async {
  await saveTelegramAdminRuntimeState(pendingDraftRuntimeState(entries));
}
