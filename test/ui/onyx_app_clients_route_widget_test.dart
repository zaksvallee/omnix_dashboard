import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'package:omnix_dashboard/application/client_camera_health_fact_packet_service.dart';
import 'package:omnix_dashboard/application/client_conversation_repository.dart';
import 'package:omnix_dashboard/application/client_messaging_bridge_repository.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';
import 'package:omnix_dashboard/application/monitoring_shift_scope_config.dart';
import 'package:omnix_dashboard/application/sms_delivery_service.dart';
import 'package:omnix_dashboard/application/telegram_ai_assistant_service.dart';
import 'package:omnix_dashboard/application/telegram_client_approval_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/incident_closed.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';
import 'package:omnix_dashboard/ui/onyx_agent_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

import 'support/admin_route_state_harness.dart';
import 'support/admin_route_test_harness.dart';
import 'support/telegram_route_assertions.dart';

DateTime _clientsTestOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 18, hour, minute);

DateTime _clientsScenarioOccurredAtUtc(int minute) =>
    _clientsTestOccurredAtUtc(20, minute);

DateTime _clientsOffScopeSyncOccurredAtUtc(int minute) =>
    _clientsTestOccurredAtUtc(13, minute);

DateTime _clientsRouteOccurredAtUtc(int minute) =>
    _clientsTestOccurredAtUtc(12, minute);

DateTime _clientsOffScopeOccurredAtUtc(int minute) =>
    DateTime.utc(2026, 3, 19, 6, minute);

DateTime _clientsQuickActionSentAtUtc(int hour, int minute) =>
    _clientsTestOccurredAtUtc(hour, minute);

DateTime _clientsScenarioNowUtc() =>
    DateTime.parse('2026-04-05T19:00:00.000Z').toUtc();

DateTime _clientsMatrixNowUtc() =>
    DateTime.parse('2026-03-18T21:59:00.000Z').toUtc();

DateTime _clientsScenarioLocalNow() => DateTime(2026, 3, 18, 23, 59);

DateTime _clientsStatusNowUtc() =>
    DateTime.parse('2026-04-07T10:31:00.000Z').toUtc();

DateTime _clientsAnchoredNowUtc(List<DispatchEvent> events) {
  if (events.isEmpty) {
    return _clientsScenarioNowUtc();
  }
  var latestEventAtUtc = events.first.occurredAt.toUtc();
  for (final event in events.skip(1)) {
    final occurredAtUtc = event.occurredAt.toUtc();
    if (occurredAtUtc.isAfter(latestEventAtUtc)) {
      latestEventAtUtc = occurredAtUtc;
    }
  }
  return latestEventAtUtc.add(const Duration(minutes: 1));
}

List<int> _placeholderTelegramSnapshotBytes() {
  final image = img.Image(width: 640, height: 360);
  img.fill(image, color: img.ColorRgb8(0, 0, 0));
  return img.encodeJpg(image, quality: 90);
}

bool _containsAnySnippet(String text, Iterable<String> snippets) =>
    snippets.any(text.contains);

List<String> _clientAreaTerms(String area) {
  final normalized = area.trim();
  if (normalized.isEmpty) {
    return const <String>[];
  }
  final terms = <String>{normalized};
  final segments = normalized.split(RegExp(r'\s+'));
  if (segments.length > 1) {
    terms.add(segments.last);
  }
  return terms.toList(growable: false);
}

bool _hasRecentActivityLead(String transcript, String area) {
  final areaTerms = _clientAreaTerms(area);
  return areaTerms.any(
        (term) =>
            transcript.contains('The latest verified activity near $term was'),
      ) ||
      areaTerms.any(
        (term) => transcript.contains(
          'The latest confirmed alert points to $term again.',
        ),
      ) ||
      (transcript.contains('The latest confirmed alert was') &&
          areaTerms.any(transcript.contains));
}

bool _hasVisualGap(String transcript, String area) {
  return transcript.contains(
        'I do not have live visual confirmation right now.',
      ) ||
      _clientAreaTerms(area).any(
        (term) => transcript.contains(
          'I do not have live visual confirmation on $term',
        ),
      );
}

bool _hasSettledSignalLead(String transcript, String area) {
  return transcript.contains('The earlier $area signal has settled.') ||
      _clientAreaTerms(area).any(
        (term) => transcript.contains('The earlier $term signal has settled.'),
      ) ||
      _clientAreaTerms(area).any(
        (term) => transcript.contains(
          'Yes. $term has been calm since the earlier signal.',
        ),
      );
}

bool _hasGenericAreaAmbiguity(String transcript) {
  return transcript.contains('I’m not fully certain which area you') ||
      transcript.contains('If you tell me which gate, entrance, or camera');
}

bool _matchesAreaAwareLead(
  String transcript, {
  required String expectedLead,
  required String area,
}) {
  if (transcript.contains(expectedLead)) {
    return true;
  }
  if (expectedLead.contains('A response arrival tied to')) {
    return transcript.contains('Yes. A response arrival was logged at ');
  }
  if (expectedLead.contains(
    'I do not have a confirmed response arrival tied to',
  )) {
    return transcript.contains(
      'I do not have a confirmed response arrival yet.',
    );
  }
  if (expectedLead.contains('I do not have a confirmed guard check tied to')) {
    return transcript.contains('I do not have a confirmed guard check yet.');
  }
  if (expectedLead.contains('The latest guard check tied to')) {
    return transcript.contains('Yes. The latest guard check was logged on') ||
        transcript.contains('Yes. The latest guard check was logged by');
  }
  if (expectedLead.startsWith('The earlier ')) {
    return transcript.contains('That earlier issue has settled.') ||
        _hasSettledSignalLead(transcript, area);
  }
  if (expectedLead.contains('The latest confirmed alert points to')) {
    return _hasRecentActivityLead(transcript, area);
  }
  return _hasRecentActivityLead(transcript, area);
}

bool _hasEnumeratedAreaFallback(String transcript, List<String> areas) {
  final hasAreaSpecificCopy = areas.every((area) {
    return _containsAnySnippet(transcript, <String>[
      'I do not have a fresh verified event tied to $area right now.',
      'I do not have a confirmed alert tied to $area earlier tonight in the current operational picture.',
      'The latest verified activity near $area was',
      'I do not have a confirmed guard check tied to $area yet.',
      'I do not have a confirmed response arrival tied to $area yet.',
    ]);
  });
  if (!hasAreaSpecificCopy) {
    return false;
  }
  return _containsAnySnippet(transcript, const <String>[
    'I do not have a confirmed response arrival tied to',
    'I do not have a confirmed guard check tied to',
    'I do not have live visual confirmation on',
    'Nothing here shows an active',
    'prioritise',
  ]);
}

Matcher _matchesLegacyAmbiguityOrEnumeratedAreaFallback({
  required RegExp legacyPattern,
  List<String> legacyFollowUps = const <String>[],
  required List<String> areas,
}) {
  return predicate<String>((transcript) {
    final hasLegacy =
        legacyPattern.hasMatch(transcript) &&
        (legacyFollowUps.isEmpty || legacyFollowUps.any(transcript.contains));
    return hasLegacy || _hasEnumeratedAreaFallback(transcript, areas);
  }, 'matches legacy ambiguity copy or enumerated area fallback');
}

class _ConfiguredTelegramBridgeStub implements TelegramBridgeService {
  const _ConfiguredTelegramBridgeStub();

  @override
  bool get isConfigured => true;

  @override
  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  }) async {
    return false;
  }

  @override
  Future<List<TelegramBridgeInboundMessage>> fetchUpdates({
    int? offset,
    int limit = 30,
    int timeoutSeconds = 0,
  }) async {
    return const <TelegramBridgeInboundMessage>[];
  }

  @override
  Future<TelegramBridgeSendResult> sendMessages({
    required List<TelegramBridgeMessage> messages,
  }) async {
    return TelegramBridgeSendResult(
      sent: const [],
      failed: messages,
      failureReasonsByMessageKey: {
        for (final message in messages)
          message.messageKey: 'BLOCKED_BY_TEST_STUB',
      },
    );
  }
}

class _DelayedFailingTelegramBridgeStub implements TelegramBridgeService {
  const _DelayedFailingTelegramBridgeStub();

  @override
  bool get isConfigured => true;

  @override
  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  }) async {
    return false;
  }

  @override
  Future<List<TelegramBridgeInboundMessage>> fetchUpdates({
    int? offset,
    int limit = 30,
    int timeoutSeconds = 0,
  }) async {
    return const <TelegramBridgeInboundMessage>[];
  }

  @override
  Future<TelegramBridgeSendResult> sendMessages({
    required List<TelegramBridgeMessage> messages,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return TelegramBridgeSendResult(
      sent: const <TelegramBridgeMessage>[],
      failed: messages,
      failureReasonsByMessageKey: {
        for (final message in messages)
          message.messageKey: 'BLOCKED_BY_TEST_STUB',
      },
    );
  }
}

class _FailingMonitoringIdentityRulesStore
    extends SharedPreferencesStorePlatform {
  _FailingMonitoringIdentityRulesStore()
    : _delegate = InMemorySharedPreferencesStore.empty();

  final InMemorySharedPreferencesStore _delegate;

  String get _failingKey =>
      'flutter.${DispatchPersistenceService.monitoringIdentityRulesJsonKey}';

  @override
  Future<bool> clear() => _delegate.clear();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      _delegate.clearWithParameters(parameters);

  @override
  Future<Map<String, Object>> getAll() => _delegate.getAll();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => _delegate.getAllWithParameters(parameters);

  @override
  Future<bool> remove(String key) => _delegate.remove(key);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == _failingKey) {
      throw StateError('simulated monitoring identity rules write failure');
    }
    return _delegate.setValue(valueType, key, value);
  }
}

class _FailingClientAcknowledgementStore
    extends SharedPreferencesStorePlatform {
  _FailingClientAcknowledgementStore.withData(Map<String, Object> data)
    : _delegate = InMemorySharedPreferencesStore.withData(data);

  final InMemorySharedPreferencesStore _delegate;

  bool _shouldFailForKey(String key) {
    return key.contains(
          DispatchPersistenceService.clientAppAcknowledgementsKey,
        ) ||
        key.contains(DispatchPersistenceService.clientAppPushQueueKey);
  }

  @override
  Future<bool> clear() => _delegate.clear();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      _delegate.clearWithParameters(parameters);

  @override
  Future<Map<String, Object>> getAll() => _delegate.getAll();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => _delegate.getAllWithParameters(parameters);

  @override
  Future<bool> remove(String key) => _delegate.remove(key);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (_shouldFailForKey(key)) {
      throw StateError('simulated client acknowledgement persistence failure');
    }
    return _delegate.setValue(valueType, key, value);
  }
}

class _FailingTelegramAdminRuntimeStore extends SharedPreferencesStorePlatform {
  _FailingTelegramAdminRuntimeStore()
    : _delegate = InMemorySharedPreferencesStore.empty();

  final InMemorySharedPreferencesStore _delegate;

  String get _failingKey =>
      'flutter.${DispatchPersistenceService.telegramAdminRuntimeStateKey}';

  @override
  Future<bool> clear() => _delegate.clear();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      _delegate.clearWithParameters(parameters);

  @override
  Future<Map<String, Object>> getAll() => _delegate.getAll();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => _delegate.getAllWithParameters(parameters);

  @override
  Future<bool> remove(String key) => _delegate.remove(key);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == _failingKey) {
      throw StateError('simulated telegram admin runtime persistence failure');
    }
    return _delegate.setValue(valueType, key, value);
  }
}

class _DelayedClientPushSyncStateStore extends SharedPreferencesStorePlatform {
  _DelayedClientPushSyncStateStore.withData(Map<String, Object> data)
    : _delegate = InMemorySharedPreferencesStore.withData(data);

  final InMemorySharedPreferencesStore _delegate;

  bool _shouldDelayKey(String key) {
    return key.contains(DispatchPersistenceService.clientAppPushSyncStateKey);
  }

  @override
  Future<bool> clear() => _delegate.clear();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      _delegate.clearWithParameters(parameters);

  @override
  Future<Map<String, Object>> getAll() => _delegate.getAll();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => _delegate.getAllWithParameters(parameters);

  @override
  Future<bool> remove(String key) => _delegate.remove(key);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (_shouldDelayKey(key)) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    return _delegate.setValue(valueType, key, value);
  }
}

class _SuccessfulSmsDeliveryStub implements SmsDeliveryService {
  const _SuccessfulSmsDeliveryStub();

  @override
  bool get isConfigured => true;

  @override
  String get providerLabel => 'sms:bulksms';

  @override
  Future<SmsDeliverySendResult> sendMessages({
    required List<SmsDeliveryMessage> messages,
  }) async {
    return SmsDeliverySendResult(sent: messages, failed: const []);
  }
}

class _DelayedSuccessfulSmsDeliveryStub implements SmsDeliveryService {
  const _DelayedSuccessfulSmsDeliveryStub();

  @override
  bool get isConfigured => true;

  @override
  String get providerLabel => 'sms:bulksms';

  @override
  Future<SmsDeliverySendResult> sendMessages({
    required List<SmsDeliveryMessage> messages,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    return SmsDeliverySendResult(sent: messages, failed: const []);
  }
}

class _RecordingTelegramBridgeStub implements TelegramBridgeService {
  final List<TelegramBridgeMessage> sentMessages = <TelegramBridgeMessage>[];

  @override
  bool get isConfigured => true;

  @override
  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  }) async {
    return true;
  }

  @override
  Future<List<TelegramBridgeInboundMessage>> fetchUpdates({
    int? offset,
    int limit = 30,
    int timeoutSeconds = 0,
  }) async {
    return const <TelegramBridgeInboundMessage>[];
  }

  @override
  Future<TelegramBridgeSendResult> sendMessages({
    required List<TelegramBridgeMessage> messages,
  }) async {
    sentMessages.addAll(messages);
    return TelegramBridgeSendResult(
      sent: messages,
      failed: const <TelegramBridgeMessage>[],
    );
  }
}

class _FixedLocalHikvisionDvrVisualProbeService
    implements LocalHikvisionDvrVisualProbeService {
  final LocalHikvisionDvrVisualProbeSnapshot snapshot;

  const _FixedLocalHikvisionDvrVisualProbeService(this.snapshot);

  @override
  Future<LocalHikvisionDvrVisualProbeSnapshot?> read(
    DvrScopeConfig scope, {
    Iterable<IntelligenceReceived> recentIntelligence =
        const <IntelligenceReceived>[],
  }) async {
    return snapshot;
  }
}

class _ScriptedTelegramAiAssistantStub implements TelegramAiAssistantService {
  const _ScriptedTelegramAiAssistantStub();

  @override
  bool get isConfigured => true;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    List<String> clientProfileSignals = const <String>[],
    List<String> preferredReplyExamples = const <String>[],
    List<String> preferredReplyStyleTags = const <String>[],
    List<String> learnedReplyExamples = const <String>[],
    List<String> learnedReplyStyleTags = const <String>[],
    List<String> recentConversationTurns = const <String>[],
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
    String? siteAwarenessContext,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
  }) async {
    final normalized = messageText.trim().toLowerCase();
    if (audience == TelegramAiAudience.client &&
        recentConversationTurns.any(
          (turn) => turn.toLowerCase().contains(
            'latest client follow-up already sent',
          ),
        )) {
      return const TelegramAiDraftReply(
        text:
            'Control is checking the front gate at MS Vallee Residence now. I will confirm here as soon as security verifies everything is okay.',
        providerLabel: 'test-ai',
      );
    }
    if (audience == TelegramAiAudience.client &&
        normalized.contains('front gate')) {
      return const TelegramAiDraftReply(
        text:
            'We are checking access at MS Vallee Residence now. I will update you here with the next confirmed step.',
        providerLabel: 'test-ai',
      );
    }
    return const TelegramAiDraftReply(
      text:
          'We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
      providerLabel: 'test-ai',
    );
  }
}

class _DraftRefiningTelegramAiAssistantStub
    implements TelegramAiAssistantService {
  const _DraftRefiningTelegramAiAssistantStub();

  @override
  bool get isConfigured => true;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    List<String> clientProfileSignals = const <String>[],
    List<String> preferredReplyExamples = const <String>[],
    List<String> preferredReplyStyleTags = const <String>[],
    List<String> learnedReplyExamples = const <String>[],
    List<String> learnedReplyStyleTags = const <String>[],
    List<String> recentConversationTurns = const <String>[],
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
    String? siteAwarenessContext,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
  }) async {
    final normalized = messageText.trim().toLowerCase();
    if (audience == TelegramAiAudience.client &&
        normalized.contains('current operator draft') &&
        normalized.contains('refine the operator draft') &&
        normalized.contains('send a unit over')) {
      return const TelegramAiDraftReply(
        text:
            'We currently do not have access to remote monitoring, so I cannot confirm visually from here. If everything looks fine on your side, please let us know, or tell us if you want us to send a unit over.',
        providerLabel: 'test-ai',
      );
    }
    if (audience == TelegramAiAudience.client &&
        recentConversationTurns.any(
          (turn) => turn.toLowerCase().contains(
            'latest client follow-up already sent',
          ),
        )) {
      return const TelegramAiDraftReply(
        text:
            'Control is checking the front gate at MS Vallee Residence now. I will confirm here as soon as security verifies everything is okay.',
        providerLabel: 'test-ai',
      );
    }
    if (audience == TelegramAiAudience.client &&
        normalized.contains('front gate')) {
      return const TelegramAiDraftReply(
        text:
            'We are checking access at MS Vallee Residence now. I will update you here with the next confirmed step.',
        providerLabel: 'test-ai',
      );
    }
    return const TelegramAiDraftReply(
      text:
          'We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
      providerLabel: 'test-ai',
    );
  }
}

Future<void> _openClientsDetailedWorkspaceIfPresent(WidgetTester tester) async {
  final workspaceBanner = find.byKey(
    const ValueKey('clients-workspace-status-banner'),
  );
  if (workspaceBanner.evaluate().isNotEmpty) {
    return;
  }
  final toggle = find.byKey(
    const ValueKey('clients-toggle-detailed-workspace'),
  );
  if (toggle.evaluate().isEmpty) {
    return;
  }
  await tester.ensureVisible(toggle.first);
  await tester.tap(toggle.first);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_RecordingTelegramBridgeStub> pumpClientTelegramPromptThroughRoute(
    WidgetTester tester, {
    required Key appKey,
    required String prompt,
    required int updateId,
    DateTime? sentAtUtc,
    DateTime? operationalNowUtc,
    String siteId = 'SITE-DEMO',
    String chatType = 'private',
    List<DispatchEvent> initialStoreEventsOverride = const <DispatchEvent>[],
    List<MonitoringShiftScopeConfig>? monitoringShiftScopeConfigsOverride,
    List<DvrScopeConfig> dvrScopeConfigsOverride = const <DvrScopeConfig>[],
    LocalHikvisionDvrVisualProbeService?
    localHikvisionDvrVisualProbeServiceOverride,
    Future<List<int>?> Function(Uri snapshotUri)?
    telegramSnapshotBytesLoaderOverride,
    bool? telegramAiAssistantEnabledOverride,
    bool? telegramAiApprovalRequiredOverride,
    TelegramAiAssistantService? telegramAiAssistantServiceOverride,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bridge = _RecordingTelegramBridgeStub();
    final effectiveSentAtUtc =
        sentAtUtc ?? _clientsAnchoredNowUtc(initialStoreEventsOverride);

    await tester.pumpWidget(
      OnyxApp(
        key: appKey,
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.clients,
        initialClientLaneClientIdOverride: 'CLIENT-DEMO',
        initialClientLaneSiteIdOverride: siteId,
        appModeOverride: OnyxAppMode.client,
        telegramBridgeServiceOverride: bridge,
        onyxTelegramOperationalNowOverride: operationalNowUtc == null
            ? null
            : () => operationalNowUtc,
        telegramChatIdOverride: 'test-client-chat',
        telegramAiAssistantServiceOverride: telegramAiAssistantServiceOverride,
        localHikvisionDvrVisualProbeServiceOverride:
            localHikvisionDvrVisualProbeServiceOverride,
        telegramSnapshotBytesLoaderOverride:
            telegramSnapshotBytesLoaderOverride,
        telegramAiAssistantEnabledOverride: telegramAiAssistantEnabledOverride,
        telegramAiApprovalRequiredOverride: telegramAiApprovalRequiredOverride,
        monitoringShiftScopeConfigsOverride:
            monitoringShiftScopeConfigsOverride ??
            <MonitoringShiftScopeConfig>[
              MonitoringShiftScopeConfig(
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: siteId,
                schedule: const MonitoringShiftSchedule(
                  enabled: true,
                  startHour: 18,
                  startMinute: 0,
                  endHour: 6,
                  endMinute: 0,
                ),
              ),
            ],
        dvrScopeConfigsOverride: dvrScopeConfigsOverride,
        initialStoreEventsOverride: initialStoreEventsOverride,
        initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
          TelegramBridgeInboundMessage(
            updateId: updateId,
            chatId: 'test-client-chat',
            chatType: chatType,
            text: prompt,
            sentAtUtc: effectiveSentAtUtc,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(bridge.sentMessages, isNotEmpty, reason: prompt);
    return bridge;
  }

  Future<String> sendClientTelegramConversationThroughRoute(
    WidgetTester tester, {
    required Key appKey,
    required List<String> prompts,
    required int firstUpdateId,
    int? minimumExpectedMessages,
    DateTime? operationalNowUtc,
    String siteId = 'SITE-DEMO',
    String chatType = 'private',
    List<DispatchEvent> initialStoreEventsOverride = const <DispatchEvent>[],
    List<MonitoringShiftScopeConfig>? monitoringShiftScopeConfigsOverride,
    List<DvrScopeConfig> dvrScopeConfigsOverride = const <DvrScopeConfig>[],
    bool? telegramAiAssistantEnabledOverride,
    bool? telegramAiApprovalRequiredOverride,
    TelegramAiAssistantService? telegramAiAssistantServiceOverride,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bridge = _RecordingTelegramBridgeStub();
    final now =
        operationalNowUtc ?? _clientsAnchoredNowUtc(initialStoreEventsOverride);

    await tester.pumpWidget(
      OnyxApp(
        key: appKey,
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.clients,
        initialClientLaneClientIdOverride: 'CLIENT-DEMO',
        initialClientLaneSiteIdOverride: siteId,
        appModeOverride: OnyxAppMode.client,
        telegramBridgeServiceOverride: bridge,
        onyxTelegramOperationalNowOverride: operationalNowUtc == null
            ? null
            : () => operationalNowUtc,
        telegramChatIdOverride: 'test-client-chat',
        telegramAiAssistantServiceOverride: telegramAiAssistantServiceOverride,
        telegramAiAssistantEnabledOverride: telegramAiAssistantEnabledOverride,
        telegramAiApprovalRequiredOverride: telegramAiApprovalRequiredOverride,
        monitoringShiftScopeConfigsOverride:
            monitoringShiftScopeConfigsOverride ??
            <MonitoringShiftScopeConfig>[
              MonitoringShiftScopeConfig(
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: siteId,
                schedule: const MonitoringShiftSchedule(
                  enabled: true,
                  startHour: 18,
                  startMinute: 0,
                  endHour: 6,
                  endMinute: 0,
                ),
              ),
            ],
        dvrScopeConfigsOverride: dvrScopeConfigsOverride,
        initialStoreEventsOverride: initialStoreEventsOverride,
        initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
          for (var index = 0; index < prompts.length; index++)
            TelegramBridgeInboundMessage(
              updateId: firstUpdateId + index,
              chatId: 'test-client-chat',
              chatType: chatType,
              text: prompts[index],
              sentAtUtc: now.add(Duration(seconds: index * 4)),
            ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      bridge.sentMessages.length,
      greaterThanOrEqualTo(minimumExpectedMessages ?? prompts.length),
    );
    return telegramTranscriptFromMessages(bridge.sentMessages);
  }

  Future<_RecordingTelegramBridgeStub> pumpPartnerTelegramPromptThroughRoute(
    WidgetTester tester, {
    required Key appKey,
    required String prompt,
    required int updateId,
    DateTime? sentAtUtc,
    DateTime? operationalNowUtc,
    List<DispatchEvent> initialStoreEventsOverride = const <DispatchEvent>[],
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bridge = _RecordingTelegramBridgeStub();
    final effectiveSentAtUtc =
        sentAtUtc ?? _clientsAnchoredNowUtc(initialStoreEventsOverride);

    await tester.pumpWidget(
      OnyxApp(
        key: appKey,
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.clients,
        initialClientLaneClientIdOverride: 'CLIENT-DEMO',
        initialClientLaneSiteIdOverride: 'SITE-DEMO',
        appModeOverride: OnyxAppMode.client,
        telegramBridgeServiceOverride: bridge,
        onyxTelegramOperationalNowOverride: operationalNowUtc == null
            ? null
            : () => operationalNowUtc,
        telegramPartnerChatIdOverride: 'test-partner-chat',
        telegramPartnerClientIdOverride: 'CLIENT-DEMO',
        telegramPartnerSiteIdOverride: 'SITE-DEMO',
        initialStoreEventsOverride: initialStoreEventsOverride,
        initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
          TelegramBridgeInboundMessage(
            updateId: updateId,
            chatId: 'test-partner-chat',
            chatType: 'group',
            text: prompt,
            sentAtUtc: effectiveSentAtUtc,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(bridge.sentMessages, isNotEmpty, reason: prompt);
    return bridge;
  }

  testWidgets(
    'onyx app still confirms verification replies when client acknowledgement persistence fails',
    (tester) async {
      final queuedVerification = ClientAppPushDeliveryItem(
        messageKey:
            '${TelegramClientApprovalService.verificationMessageKeyPrefix}-route-test',
        title: 'Verification required',
        body: 'Please confirm this visitor.',
        occurredAt: DateTime.utc(2026, 4, 5, 19, 2),
        clientId: 'CLIENT-DEMO',
        siteId: 'SITE-DEMO',
        targetChannel: ClientAppAcknowledgementChannel.client,
        deliveryProvider: ClientPushDeliveryProvider.telegram,
        priority: true,
        status: ClientPushDeliveryStatus.queued,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        DispatchPersistenceService.clientAppPushQueueKey: jsonEncode(<Object?>[
          queuedVerification.toJson(),
        ]),
      });
      SharedPreferencesStorePlatform.instance =
          _FailingClientAcknowledgementStore.withData(<String, Object>{
            'flutter.${DispatchPersistenceService.clientAppPushQueueKey}':
                jsonEncode(<Object?>[queuedVerification.toJson()]),
          });
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bridge = _RecordingTelegramBridgeStub();
      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('telegram-client-verification-ack-failure'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'SITE-DEMO',
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: bridge,
          telegramAdminChatIdOverride: 'test-admin-chat',
          telegramChatIdOverride: 'test-client-chat',
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 9202,
              chatId: 'test-client-chat',
              chatType: 'private',
              text: 'approve',
              sentAtUtc: DateTime.utc(2026, 4, 5, 19, 3),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final transcript = telegramTranscriptFromMessages(bridge.sentMessages);
      expect(
        transcript,
        contains(
          'ONYX received your approval. Control has logged this person as expected and will continue monitoring.',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app still confirms allow-once replies when client acknowledgement persistence fails',
    (tester) async {
      final queuedAllowance = ClientAppPushDeliveryItem(
        messageKey:
            '${TelegramClientApprovalService.allowanceMessageKeyPrefix}-route-test',
        title: 'Allowlist option',
        body: 'Would you like ONYX to remember this visitor?',
        occurredAt: DateTime.utc(2026, 4, 5, 19, 8),
        clientId: 'CLIENT-DEMO',
        siteId: 'SITE-DEMO',
        targetChannel: ClientAppAcknowledgementChannel.client,
        deliveryProvider: ClientPushDeliveryProvider.telegram,
        priority: true,
        status: ClientPushDeliveryStatus.queued,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        DispatchPersistenceService.clientAppPushQueueKey: jsonEncode(<Object?>[
          queuedAllowance.toJson(),
        ]),
      });
      SharedPreferencesStorePlatform.instance =
          _FailingClientAcknowledgementStore.withData(<String, Object>{
            'flutter.${DispatchPersistenceService.clientAppPushQueueKey}':
                jsonEncode(<Object?>[queuedAllowance.toJson()]),
          });
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bridge = _RecordingTelegramBridgeStub();
      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('telegram-client-allow-once-ack-failure'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'SITE-DEMO',
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: bridge,
          telegramAdminChatIdOverride: 'test-admin-chat',
          telegramChatIdOverride: 'test-client-chat',
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 9203,
              chatId: 'test-client-chat',
              chatType: 'private',
              text: 'allow once',
              sentAtUtc: DateTime.utc(2026, 4, 5, 19, 9),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final transcript = telegramTranscriptFromMessages(bridge.sentMessages);
      expect(
        transcript,
        contains(
          'ONYX logged this as a one-time approved visitor. We will ask again if the same person appears later.',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app still confirms always-allow replies when local identity rule persistence fails',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance =
          _FailingMonitoringIdentityRulesStore();
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      final conversation = SharedPrefsClientConversationRepository(persistence);
      final occurredAtUtc = DateTime.utc(2026, 4, 5, 18, 52);
      await conversation.savePushQueue(<ClientAppPushDeliveryItem>[
        ClientAppPushDeliveryItem(
          messageKey:
              '${TelegramClientApprovalService.allowanceMessageKeyPrefix}-route-test',
          title: 'Allowlist option',
          body: 'Would you like ONYX to remember this visitor?',
          occurredAt: occurredAtUtc,
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          targetChannel: ClientAppAcknowledgementChannel.client,
          deliveryProvider: ClientPushDeliveryProvider.telegram,
          priority: true,
          status: ClientPushDeliveryStatus.queued,
        ),
      ]);

      final bridge = _RecordingTelegramBridgeStub();
      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('telegram-client-always-allow-prefs-failure'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'SITE-DEMO',
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: bridge,
          telegramAdminChatIdOverride: 'test-admin-chat',
          telegramChatIdOverride: 'test-client-chat',
          initialStoreEventsOverride: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'allow-always-route-event',
              sequence: 1,
              version: 1,
              occurredAt: occurredAtUtc,
              intelligenceId: 'INT-ALLOW-ALWAYS-1',
              provider: 'hik_connect',
              sourceType: 'alarm',
              externalId: 'evt-allow-always-1',
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
              objectLabel: 'person',
              faceMatchId: 'FACE-RESIDENT-44',
              headline: 'Unknown person detected',
              summary: 'Resident verification requested.',
              riskScore: 61,
              canonicalHash: 'allow-always-hash-1',
            ),
          ],
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 9201,
              chatId: 'test-client-chat',
              chatType: 'private',
              text: 'always allow',
              sentAtUtc: occurredAtUtc.add(const Duration(minutes: 1)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final transcript = telegramTranscriptFromMessages(bridge.sentMessages);
      expect(
        transcript,
        contains(
          'ONYX saved this visitor to the site allowlist and will treat future matches as expected.',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app rejects client fallback telegram prompts from the wrong topic thread',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bridge = _RecordingTelegramBridgeStub();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('telegram-client-thread-mismatch-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'SITE-DEMO',
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: bridge,
          telegramAdminChatIdOverride: 'test-admin-chat',
          telegramChatIdOverride: 'test-client-chat',
          telegramMessageThreadIdOverride: 44,
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 9199,
              chatId: 'test-client-chat',
              chatType: 'group',
              messageThreadId: 77,
              text: 'whats happening now?',
              sentAtUtc: _clientsScenarioNowUtc(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(bridge.sentMessages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app rejects client fallback telegram prompts when no explicit client lane scope is configured',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bridge = _RecordingTelegramBridgeStub();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('telegram-client-unscoped-fallback-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: bridge,
          telegramChatIdOverride: 'test-client-chat',
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 9198,
              chatId: 'test-client-chat',
              chatType: 'private',
              text: 'whats happening now?',
              sentAtUtc: _clientsScenarioNowUtc(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(bridge.sentMessages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app does not treat client chat slash commands as admin commands when no admin chat is configured',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bridge = _RecordingTelegramBridgeStub();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('telegram-client-no-admin-fallback-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'SITE-DEMO',
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: bridge,
          telegramChatIdOverride: 'test-client-chat',
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 9200,
              chatId: 'test-client-chat',
              chatType: 'private',
              fromUserId: 77,
              text: '/whoami',
              sentAtUtc: _clientsScenarioNowUtc(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(bridge.sentMessages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app rejects partner fallback telegram prompts when no explicit partner scope is configured',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bridge = _RecordingTelegramBridgeStub();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('telegram-partner-unscoped-fallback-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: bridge,
          telegramPartnerChatIdOverride: 'test-partner-chat',
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 9202,
              chatId: 'test-partner-chat',
              chatType: 'group',
              text: 'show dispatches today',
              sentAtUtc: _clientsScenarioNowUtc(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(bridge.sentMessages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app sends the current verified frame when a resident asks for an image',
    (tester) async {
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('telegram-client-image-request'),
        prompt: 'send image here',
        updateId: 9101,
        dvrScopeConfigsOverride: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri.parse(
              'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'none',
            username: '',
            password: '',
            bearerToken: '',
            cameraLabels: const <String, String>{'channel-11': 'Camera 11'},
          ),
        ],
        localHikvisionDvrVisualProbeServiceOverride:
            _FixedLocalHikvisionDvrVisualProbeService(
              LocalHikvisionDvrVisualProbeSnapshot(
                snapshotUri: Uri.parse(
                  'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
                ),
                cameraId: 'channel-11',
                reachable: true,
                verifiedAtUtc: DateTime.utc(2026, 4, 4, 10, 46),
              ),
            ),
        telegramSnapshotBytesLoaderOverride: (_) async => const <int>[
          1,
          2,
          3,
          4,
        ],
      );

      final photoMessages = bridge.sentMessages
          .where((message) => message.isPhoto)
          .toList(growable: false);
      expect(photoMessages, hasLength(1));
      expect(photoMessages.single.photoBytes, const <int>[1, 2, 3, 4]);
      expect(
        photoMessages.single.text,
        'Current verified frame from Camera 11 at Site Demo.',
      );
    },
  );

  testWidgets(
    'onyx app does not send the current frame immediately for movement-image requests',
    (tester) async {
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('telegram-client-image-watch-request'),
        prompt: 'send image on movement/s',
        updateId: 9102,
        dvrScopeConfigsOverride: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri.parse(
              'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'none',
            username: '',
            password: '',
            bearerToken: '',
            cameraLabels: const <String, String>{'channel-11': 'Camera 11'},
          ),
        ],
        localHikvisionDvrVisualProbeServiceOverride:
            _FixedLocalHikvisionDvrVisualProbeService(
              LocalHikvisionDvrVisualProbeSnapshot(
                snapshotUri: Uri.parse(
                  'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
                ),
                cameraId: 'channel-11',
                reachable: true,
                verifiedAtUtc: DateTime.utc(2026, 4, 4, 11, 15),
              ),
            ),
        telegramSnapshotBytesLoaderOverride: (_) async => const <int>[
          1,
          2,
          3,
          4,
        ],
      );

      expect(bridge.sentMessages.where((message) => message.isPhoto), isEmpty);
      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n---\n');
      expect(sentTranscript, contains('not treating that'));
      expect(sentTranscript, contains('send image here'));
    },
  );

  testWidgets(
    'onyx app blocks placeholder current frames from being sent to residents',
    (tester) async {
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('telegram-client-image-placeholder-block'),
        prompt: 'send image here',
        updateId: 9103,
        dvrScopeConfigsOverride: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri.parse(
              'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'none',
            username: '',
            password: '',
            bearerToken: '',
            cameraLabels: const <String, String>{'channel-11': 'Camera 11'},
          ),
        ],
        localHikvisionDvrVisualProbeServiceOverride:
            _FixedLocalHikvisionDvrVisualProbeService(
              LocalHikvisionDvrVisualProbeSnapshot(
                snapshotUri: Uri.parse(
                  'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
                ),
                cameraId: 'channel-11',
                reachable: true,
                verifiedAtUtc: DateTime.utc(2026, 4, 4, 11, 16),
              ),
            ),
        telegramSnapshotBytesLoaderOverride: (_) async =>
            _placeholderTelegramSnapshotBytes(),
      );

      expect(bridge.sentMessages.where((message) => message.isPhoto), isEmpty);
      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n---\n');
      expect(
        sentTranscript,
        contains(
          'I do not have a usable current verified image to send right now.',
        ),
      );
    },
  );

  testWidgets(
    'onyx app falls back to the latest usable event image when the current frame is unusable',
    (tester) async {
      final eventSnapshotUri = Uri.parse(
        'http://127.0.0.1:11635/evidence/event-1411.jpg',
      );
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('telegram-client-image-event-fallback'),
        prompt: 'send image',
        updateId: 9104,
        initialStoreEventsOverride: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'vallee-event-image-1',
            sequence: 1,
            version: 1,
            occurredAt: DateTime.utc(2026, 4, 4, 12, 11),
            intelligenceId: 'INT-VALLEE-IMAGE-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-vallee-image-1',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            cameraId: 'channel-11',
            headline: 'Motion event on Camera 11',
            summary: 'Motion was logged on Camera 11.',
            riskScore: 51,
            snapshotUrl: eventSnapshotUri.toString(),
            canonicalHash: 'hash-vallee-event-image-1',
          ),
        ],
        dvrScopeConfigsOverride: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri.parse(
              'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'none',
            username: '',
            password: '',
            bearerToken: '',
            cameraLabels: const <String, String>{'channel-11': 'Camera 11'},
          ),
        ],
        localHikvisionDvrVisualProbeServiceOverride:
            _FixedLocalHikvisionDvrVisualProbeService(
              LocalHikvisionDvrVisualProbeSnapshot(
                snapshotUri: Uri.parse(
                  'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
                ),
                cameraId: 'channel-11',
                reachable: true,
                verifiedAtUtc: DateTime.utc(2026, 4, 4, 12, 12),
              ),
            ),
        telegramSnapshotBytesLoaderOverride: (uri) async {
          if (uri == eventSnapshotUri) {
            return const <int>[9, 8, 7, 6];
          }
          return _placeholderTelegramSnapshotBytes();
        },
      );

      final photoMessages = bridge.sentMessages
          .where((message) => message.isPhoto)
          .toList(growable: false);
      expect(photoMessages, hasLength(1));
      expect(photoMessages.single.photoBytes, const <int>[9, 8, 7, 6]);
      expect(
        photoMessages.single.text,
        'Latest event image from Camera 11 at Demo from 14:11.',
      );
    },
  );

  testWidgets(
    'onyx app sends the requested event image when the resident anchors a time',
    (tester) async {
      final eventSnapshotUri = Uri.parse(
        'http://127.0.0.1:11635/evidence/event-1411.jpg',
      );
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('telegram-client-event-image-request'),
        prompt: 'send image of event at 14:11',
        updateId: 9105,
        initialStoreEventsOverride: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'vallee-event-image-2',
            sequence: 1,
            version: 1,
            occurredAt: DateTime.utc(2026, 4, 4, 12, 11),
            intelligenceId: 'INT-VALLEE-IMAGE-2',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-vallee-image-2',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            cameraId: 'channel-11',
            headline: 'Motion event on Camera 11',
            summary: 'Motion was logged on Camera 11.',
            riskScore: 51,
            snapshotUrl: eventSnapshotUri.toString(),
            canonicalHash: 'hash-vallee-event-image-2',
          ),
        ],
        telegramSnapshotBytesLoaderOverride: (uri) async {
          if (uri == eventSnapshotUri) {
            return const <int>[5, 6, 7, 8];
          }
          return null;
        },
      );

      final photoMessages = bridge.sentMessages
          .where((message) => message.isPhoto)
          .toList(growable: false);
      expect(photoMessages, hasLength(1));
      expect(photoMessages.single.photoBytes, const <int>[5, 6, 7, 8]);
      expect(
        photoMessages.single.text,
        'Event image from Camera 11 at Demo from 14:11.',
      );
    },
  );

  testWidgets(
    'onyx app explains recorded event visuals when no usable export can be sent',
    (tester) async {
      final eventSnapshotUri = Uri.parse(
        'http://127.0.0.1:11635/evidence/event-1411.jpg',
      );
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('telegram-client-image-event-visuals-unusable'),
        prompt: 'send image',
        updateId: 9106,
        initialStoreEventsOverride: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'vallee-event-image-3',
            sequence: 1,
            version: 1,
            occurredAt: DateTime.utc(2026, 4, 4, 12, 11),
            intelligenceId: 'INT-VALLEE-IMAGE-3',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'evt-vallee-image-3',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            cameraId: 'channel-11',
            headline: 'Motion event on Camera 11',
            summary: 'Motion was logged on Camera 11.',
            riskScore: 51,
            snapshotUrl: eventSnapshotUri.toString(),
            canonicalHash: 'hash-vallee-event-image-3',
          ),
        ],
        dvrScopeConfigsOverride: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri.parse(
              'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'none',
            username: '',
            password: '',
            bearerToken: '',
            cameraLabels: const <String, String>{'channel-11': 'Camera 11'},
          ),
        ],
        localHikvisionDvrVisualProbeServiceOverride:
            _FixedLocalHikvisionDvrVisualProbeService(
              LocalHikvisionDvrVisualProbeSnapshot(
                snapshotUri: Uri.parse(
                  'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
                ),
                cameraId: 'channel-11',
                reachable: true,
                verifiedAtUtc: DateTime.utc(2026, 4, 4, 12, 12),
              ),
            ),
        telegramSnapshotBytesLoaderOverride: (uri) async {
          if (uri.path.contains('/ISAPI/Streaming/channels/1101/picture')) {
            return _placeholderTelegramSnapshotBytes();
          }
          if (uri == eventSnapshotUri) {
            return null;
          }
          return null;
        },
      );

      expect(bridge.sentMessages.where((message) => message.isPhoto), isEmpty);
      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n---\n');
      expect(sentTranscript, contains('recorded event visuals'));
      expect(sentTranscript, contains('usable exported image'));
    },
  );

  testWidgets(
    'onyx app escalates acute danger resident prompts with immediate safety guidance',
    (tester) async {
      final scenarios = <({String prompt, List<String> expected})>[
        (
          prompt: 'i heard sounds of glass breaking, can you check?',
          expected: const <String>[
            'Understood. This has been escalated to the control room now.',
            'move to safety if you can',
            'call SAPS or 112 now',
          ],
        ),
        (
          prompt: 'i think someone is in the house',
          expected: const <String>[
            'Understood. This has been escalated to the control room now.',
            'move to safety if you can',
            'call SAPS or 112 now',
          ],
        ),
        (
          prompt: 'help!!!!! aaaaah',
          expected: const <String>[
            'Understood. This has been escalated to the control room now.',
            'move to safety if you can',
            'call SAPS or 112 now',
          ],
        ),
        (
          prompt: 'help whats happening on site?',
          expected: const <String>[
            'Understood. This has been escalated to the control room now.',
            'move to safety if you can',
            'call SAPS or 112 now',
          ],
        ),
        (
          prompt: 'i just got robbed',
          expected: const <String>[
            'Understood. This has been escalated to the control room now.',
            'move to safety if you can',
            'call SAPS or 112 now',
          ],
        ),
        (
          prompt: 'call the police',
          expected: const <String>[
            'Understood. This has been escalated to the control room now.',
            'If you need police immediately, call SAPS or 112 now.',
          ],
        ),
      ];

      for (var index = 0; index < scenarios.length; index += 1) {
        final scenario = scenarios[index];
        final bridge = await pumpClientTelegramPromptThroughRoute(
          tester,
          appKey: ValueKey('telegram-client-high-risk-escalation-$index'),
          prompt: scenario.prompt,
          updateId: 9200 + index,
        );

        final sentTranscript = bridge.sentMessages
            .map((message) => message.text)
            .join('\n---\n');
        for (final text in scenario.expected) {
          expect(sentTranscript, contains(text), reason: scenario.prompt);
        }
        expect(
          sentTranscript,
          isNot(contains('local camera bridge is offline')),
          reason: scenario.prompt,
        );
        expect(
          sentTranscript,
          isNot(contains('staying close on this')),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets(
    'onyx app keeps historical robbery awareness prompts in incident review instead of live escalation',
    (tester) async {
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('telegram-client-historical-robbery-review'),
        prompt: 'are you aware of the robbery earlier today?',
        updateId: 9306,
      );

      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n---\n');
      expect(
        sentTranscript,
        contains('earlier reported incident, not a live emergency'),
      );
      expect(
        sentTranscript,
        isNot(
          contains(
            'Understood. This has been escalated to the control room now.',
          ),
        ),
      );
      expect(sentTranscript, isNot(contains('move to safety if you can')));
      expect(sentTranscript, isNot(contains('call SAPS or 112 now')));
    },
  );

  testWidgets(
    'onyx app does not escalate hypothetical help capability questions',
    (tester) async {
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey(
          'telegram-client-hypothetical-escalation-capability',
        ),
        prompt: 'if i need help, can you escalate?',
        updateId: 9307,
        telegramAiAssistantEnabledOverride: true,
        telegramAiAssistantServiceOverride:
            const UnconfiguredTelegramAiAssistantService(),
      );

      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n---\n');
      expect(
        sentTranscript,
        contains('This message has not triggered an escalation by itself.'),
      );
      expect(
        sentTranscript,
        isNot(
          contains(
            'Understood. This has been escalated to the control room now.',
          ),
        ),
      );
      expect(sentTranscript, isNot(contains('ONYX AI escalation')));
      expect(sentTranscript, isNot(contains('move to safety if you can')));
    },
  );

  Future<void> pumpOffScopeClientLane(
    WidgetTester tester, {
    required Key appKey,
    List<DispatchEvent> initialStoreEventsOverride = const <DispatchEvent>[],
  }) async {
    await tester.pumpWidget(
      OnyxApp(
        key: appKey,
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.clients,
        initialClientLaneClientIdOverride: 'CLIENT-DEMO',
        initialClientLaneSiteIdOverride: 'WTF-MAIN',
        appModeOverride: OnyxAppMode.client,
        initialStoreEventsOverride: initialStoreEventsOverride,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'onyx app keeps client handoff, command routing, and review surfaces deterministic across clients and ledger surfaces',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedRoom;
      String? openedClientId;
      String? openedSiteId;
      List<String>? openedEventIds;
      String? openedSelectedEventId;
      String? openedScopeMode;

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          onClientRoomRouteOpened: (room, clientId, siteId) {
            openedRoom = room;
            openedClientId = clientId;
            openedSiteId = siteId;
          },
          onEventsScopeOpened: (eventIds, selectedEventId, scopeMode) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
            openedScopeMode = scopeMode;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Client Communications'), findsWidgets);
      await _openClientsDetailedWorkspaceIfPresent(tester);

      final residentsRoom = find.byKey(
        const ValueKey('clients-room-Residents'),
      );
      await tester.scrollUntilVisible(
        residentsRoom,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(residentsRoom);
      await tester.pumpAndSettle();

      expect(openedRoom, 'Residents');
      expect(openedClientId, 'CLIENT-DEMO');
      expect(openedSiteId, 'SITE-DEMO');

      final incidentResolvedRow = find
          .ancestor(
            of: find.text('Incident Resolved').first,
            matching: find.byType(InkWell),
          )
          .first;
      final incidentInkWell = tester.widget<InkWell>(incidentResolvedRow);
      expect(incidentInkWell.onTap, isNotNull);
      incidentInkWell.onTap!.call();
      await tester.pumpAndSettle();

      expect(openedEventIds, <String>['CLOSE-4']);
      expect(openedSelectedEventId, 'CLOSE-4');
      expect(openedScopeMode, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.ledger,
          initialPinnedLedgerAuditEntryOverride: SovereignLedgerPinnedAuditEntry(
            auditId: 'OPS-AUDIT-COMMS-1',
            clientId: 'CLIENT-DEMO',
            siteId: 'SITE-DEMO',
            recordCode: 'OB-AUDIT',
            title: 'Client handoff opened from Live Ops.',
            description:
                'Opened the client handoff for DSP-4 from the Live Ops war room.',
            occurredAt: DateTime.utc(2026, 3, 27, 22, 57),
            actorLabel: 'Control-1',
            sourceLabel: 'Live Ops War Room',
            hash: 'liveopsclienthash1',
            previousHash: 'liveopsclientprev1',
            accent: const Color(0xFF22D3EE),
            payload: const <String, Object?>{
              'type': 'live_ops_auto_audit',
              'action': 'client_handoff_opened',
              'dispatch_id': 'DSP-4',
              'incident_reference': 'INC-DSP-4',
              'source_route': 'dashboard',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sovereign Ledger'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('ledger-entry-open-live-ops-client-handoff')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ledger-entry-open-live-ops-client-handoff')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ClientsPage), findsOneWidget);
      await _openClientsDetailedWorkspaceIfPresent(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('clients-workspace-status-banner')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Client Communications'), findsWidgets);
      expect(find.text('EVIDENCE RETURN'), findsOneWidget);
      expect(find.text('LIVE OPS RETURN'), findsOneWidget);
      expect(
        find.text('Returned to client handoff for DSP-4.'),
        findsOneWidget,
      );

      final returnCases =
          <
            ({
              OnyxRoute initialRoute,
              SovereignLedgerPinnedAuditEntry? pinnedAuditEntry,
              ClientAppEvidenceReturnReceipt? receiptOverride,
              List<String> singleTexts,
              List<String> containedTexts,
            })
          >[
            (
              initialRoute: OnyxRoute.clients,
              pinnedAuditEntry: null,
              receiptOverride: const ClientAppEvidenceReturnReceipt(
                auditId: 'client-room-audit-2',
                clientId: 'CLIENT-DEMO',
                siteId: 'SITE-DEMO',
                label: 'EVIDENCE RETURN',
                headline: 'Returned to the Security Desk lane from evidence.',
                detail:
                    'The signed room handoff was verified in the ledger. Keep the same lane open and finish the room reply from here.',
                room: 'Security Desk',
                accent: Color(0xFF22D3EE),
              ),
              singleTexts: const <String>[
                'EVIDENCE RETURN',
                'Focus lane: Security Desk',
              ],
              containedTexts: const <String>[],
            ),
            (
              initialRoute: OnyxRoute.ledger,
              pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
                auditId: 'OPS-AUDIT-COMMS-ROOM-1',
                clientId: 'CLIENT-DEMO',
                siteId: 'SITE-DEMO',
                recordCode: 'OB-AUDIT',
                title: 'Client handoff opened from Live Ops.',
                description:
                    'Opened the client room handoff for DSP-4 from the Live Ops war room.',
                occurredAt: DateTime.utc(2026, 3, 27, 23, 7),
                actorLabel: 'Control-1',
                sourceLabel: 'Live Ops War Room',
                hash: 'liveopsclientroomhash1',
                previousHash: 'liveopsclientroomprev1',
                accent: const Color(0xFF22D3EE),
                payload: const <String, Object?>{
                  'type': 'live_ops_auto_audit',
                  'action': 'client_handoff_opened',
                  'dispatch_id': 'DSP-4',
                  'incident_reference': 'INC-DSP-4',
                  'source_route': 'dashboard',
                  'room': 'Security Desk',
                },
              ),
              receiptOverride: null,
              singleTexts: const <String>[
                'EVIDENCE RETURN',
                'Focus lane: Security Desk',
              ],
              containedTexts: const <String>[
                'Returned to client room for DSP-4.',
                'LIVE OPS RETURN',
              ],
            ),
            (
              initialRoute: OnyxRoute.ledger,
              pinnedAuditEntry: SovereignLedgerPinnedAuditEntry(
                auditId: 'DSP-AUDIT-COMMS-ROOM-1',
                clientId: 'CLIENT-DEMO',
                siteId: 'SITE-DEMO',
                recordCode: 'OB-AUDIT',
                title: 'Client handoff opened from Dispatch.',
                description:
                    'Opened the client room handoff for DSP-4 from the Dispatch war room.',
                occurredAt: DateTime.utc(2026, 3, 27, 23, 11),
                actorLabel: 'Control-1',
                sourceLabel: 'Dispatch War Room',
                hash: 'dispatchclientroomhash1',
                previousHash: 'dispatchclientroomprev1',
                accent: const Color(0xFF22D3EE),
                payload: const <String, Object?>{
                  'type': 'dispatch_auto_audit',
                  'action': 'client_handoff_opened',
                  'dispatch_id': 'DSP-4',
                  'incident_reference': 'INC-DSP-4',
                  'source_route': 'dispatches',
                  'room': 'Security Desk',
                },
              ),
              receiptOverride: null,
              singleTexts: const <String>[
                'EVIDENCE RETURN',
                'Focus lane: Security Desk',
              ],
              containedTexts: const <String>[
                'Returned to client room for DSP-4.',
                'DISPATCH RETURN',
              ],
            ),
          ];

      for (final scenario in returnCases) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          OnyxApp(
            supabaseReady: false,
            initialRouteOverride: scenario.initialRoute,
            initialClientLaneClientIdOverride: 'CLIENT-DEMO',
            initialClientLaneSiteIdOverride: 'SITE-DEMO',
            appModeOverride: OnyxAppMode.client,
            initialPinnedLedgerAuditEntryOverride: scenario.pinnedAuditEntry,
            initialClientAppEvidenceReturnReceiptOverride:
                scenario.receiptOverride,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ClientAppPage), findsOneWidget);
        expect(
          find.byKey(const ValueKey('client-app-evidence-return-banner')),
          findsOneWidget,
        );
        for (final text in scenario.singleTexts) {
          expect(find.text(text), findsOneWidget);
        }
        for (final text in scenario.containedTexts) {
          expect(find.textContaining(text), findsWidgets);
        }
      }

      final cases =
          <
            ({
              Key actionKey,
              List<DispatchEvent> events,
              String focusIncidentReference,
              String label,
              bool expectOperatorTitle,
            })
          >[
            (
              actionKey: const ValueKey('clients-open-agent-button'),
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'evt-client-agent-1',
                  sequence: 22,
                  version: 1,
                  occurredAt: _clientsScenarioOccurredAtUtc(24),
                  intelligenceId: 'INC-CLIENT-AGENT-77',
                  provider: 'telegram',
                  sourceType: 'telegram',
                  externalId: 'ext-client-agent-1',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                  headline: 'Resident lane requests an urgent verified update.',
                  summary:
                      'Command should escalate the active comms lane into Agent.',
                  riskScore: 68,
                  canonicalHash: 'hash-client-agent-1',
                ),
              ],
              focusIncidentReference: 'INC-CLIENT-AGENT-77',
              label: 'command hero',
              expectOperatorTitle: true,
            ),
            (
              actionKey: const ValueKey(
                'clients-incident-redraft-agent-evt-client-redraft-1',
              ),
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'evt-client-redraft-1',
                  sequence: 24,
                  version: 1,
                  occurredAt: _clientsScenarioOccurredAtUtc(28),
                  intelligenceId: 'INC-CLIENT-REDRAFT-88',
                  provider: 'telegram',
                  sourceType: 'telegram',
                  externalId: 'ext-client-redraft-1',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                  headline: 'Resident asks for a calmer rewritten update.',
                  summary:
                      'The detailed comms history should be able to redraft through Agent.',
                  riskScore: 63,
                  canonicalHash: 'hash-client-redraft-1',
                ),
              ],
              focusIncidentReference: 'INC-CLIENT-REDRAFT-88',
              label: 'advisory redraft action',
              expectOperatorTitle: false,
            ),
            (
              actionKey: const ValueKey('clients-thread-open-agent'),
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'evt-client-thread-agent-1',
                  sequence: 25,
                  version: 1,
                  occurredAt: _clientsScenarioOccurredAtUtc(29),
                  intelligenceId: 'INC-CLIENT-THREAD-91',
                  provider: 'telegram',
                  sourceType: 'telegram',
                  externalId: 'ext-client-thread-agent-1',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                  headline: 'Thread context needs a rewritten client update.',
                  summary:
                      'Detailed comms thread block should open Agent without using the feed row.',
                  riskScore: 61,
                  canonicalHash: 'hash-client-thread-agent-1',
                ),
              ],
              focusIncidentReference: 'INC-CLIENT-THREAD-91',
              label: 'thread context action',
              expectOperatorTitle: false,
            ),
            (
              actionKey: const ValueKey(
                'clients-incident-open-agent-decision-client-agent-1',
              ),
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'decision-client-agent-1',
                  sequence: 21,
                  version: 1,
                  occurredAt: _clientsScenarioOccurredAtUtc(18),
                  dispatchId: 'DSP-CLIENT-AGENT-42',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
                IntelligenceReceived(
                  eventId: 'evt-client-agent-1',
                  sequence: 22,
                  version: 1,
                  occurredAt: _clientsScenarioOccurredAtUtc(24),
                  intelligenceId: 'INC-CLIENT-AGENT-77',
                  provider: 'telegram',
                  sourceType: 'telegram',
                  externalId: 'ext-client-agent-1',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                  headline: 'Resident lane requests an urgent verified update.',
                  summary:
                      'Command should escalate the active comms lane into Agent.',
                  riskScore: 68,
                  canonicalHash: 'hash-client-agent-1',
                ),
              ],
              focusIncidentReference: 'DSP-CLIENT-AGENT-42',
              label: 'incident feed row action',
              expectOperatorTitle: true,
            ),
          ];

      for (final scenario in cases) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          OnyxApp(
            supabaseReady: false,
            initialRouteOverride: OnyxRoute.clients,
            initialClientLaneClientIdOverride: 'CLIENT-DEMO',
            initialClientLaneSiteIdOverride: 'SITE-DEMO',
            initialStoreEventsOverride: scenario.events,
          ),
        );
        await tester.pumpAndSettle();
        await _openClientsDetailedWorkspaceIfPresent(tester);

        final agentAction = find.byKey(scenario.actionKey);
        expect(agentAction, findsOneWidget, reason: scenario.label);
        await tester.ensureVisible(agentAction);
        await tester.tap(agentAction);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byType(OnyxAgentPage), findsOneWidget);
        if (scenario.expectOperatorTitle) {
          expect(find.text('Junior Analyst'), findsOneWidget);
        }
        expect(
          tester
              .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
              .sourceRouteLabel,
          'Clients',
        );
        expect(
          tester
              .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
              .scopeClientId,
          'CLIENT-DEMO',
        );
        expect(
          tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeSiteId,
          'SITE-DEMO',
        );
        expect(
          tester
              .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
              .focusIncidentReference,
          scenario.focusIncidentReference,
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'SITE-DEMO',
          initialStoreEventsOverride: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-client-agent-resume-1',
              sequence: 23,
              version: 1,
              occurredAt: _clientsScenarioOccurredAtUtc(29),
              intelligenceId: 'INC-CLIENT-AGENT-88',
              provider: 'telegram',
              sourceType: 'telegram',
              externalId: 'ext-client-agent-resume-1',
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
              headline: 'Resident lane needs a direct comms resume path.',
              summary:
                  'The Agent header should return the controller to Clients.',
              riskScore: 61,
              canonicalHash: 'hash-client-agent-resume-1',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openClientsDetailedWorkspaceIfPresent(tester);

      final agentAction = find.byKey(
        const ValueKey('clients-open-agent-button'),
      );
      await tester.ensureVisible(agentAction);
      await tester.tap(agentAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(OnyxAgentPage), findsOneWidget);
      expect(
        tester
            .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
            .sourceRouteLabel,
        'Clients',
      );
      expect(
        tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeClientId,
        'CLIENT-DEMO',
      );
      expect(
        tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeSiteId,
        'SITE-DEMO',
      );
      expect(
        tester
            .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
            .focusIncidentReference,
        'INC-CLIENT-AGENT-88',
      );

      final resumeCommsButton = find.byKey(
        const ValueKey('onyx-agent-resume-comms-button'),
      );
      await tester.ensureVisible(resumeCommsButton);
      await tester.tap(resumeCommsButton);
      await tester.pumpAndSettle();

      await _openClientsDetailedWorkspaceIfPresent(tester);

      expect(find.byType(ClientsPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('clients-open-agent-button')),
        findsOneWidget,
      );
      expect(find.text('Client Communications'), findsWidgets);
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).clientId,
        'CLIENT-DEMO',
      );
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).siteId,
        'SITE-DEMO',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'SITE-DEMO',
          initialStoreEventsOverride: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-client-agent-handoff-3',
              sequence: 24,
              version: 1,
              occurredAt: _clientsScenarioOccurredAtUtc(34),
              intelligenceId: 'INC-CLIENT-AGENT-101',
              provider: 'telegram',
              sourceType: 'telegram',
              externalId: 'ext-client-agent-handoff-3',
              clientId: 'CLIENT-DEMO',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-DEMO',
              headline: 'Resident lane needs a resumed detailed comms review.',
              summary:
                  'Focused queue draft should reopen the detailed communications board.',
              riskScore: 66,
              canonicalHash: 'hash-client-agent-handoff-3',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _openClientsDetailedWorkspaceIfPresent(tester);

      final heroAgentAction = find.byKey(
        const ValueKey('clients-open-agent-button'),
      );
      await tester.ensureVisible(heroAgentAction);
      await tester.tap(heroAgentAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(OnyxAgentPage), findsOneWidget);
      expect(
        tester
            .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
            .sourceRouteLabel,
        'Clients',
      );
      expect(
        tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeClientId,
        'CLIENT-DEMO',
      );
      expect(
        tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeSiteId,
        'SITE-DEMO',
      );
      expect(
        tester
            .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
            .focusIncidentReference,
        'INC-CLIENT-AGENT-101',
      );

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Draft a detailed comms follow-up for the current incident',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final refineDraftAction = find.byKey(
        const ValueKey('onyx-agent-action-draft-client-reply'),
      );
      final messageListScrollable = find.descendant(
        of: find.byKey(const ValueKey('onyx-agent-message-list')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        refineDraftAction,
        220,
        scrollable: messageListScrollable,
      );
      final refineDraftButton = tester.widget<OutlinedButton>(
        refineDraftAction,
      );
      expect(refineDraftButton.onPressed, isNotNull);
      refineDraftButton.onPressed!.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final reopenCommsAction = find.byKey(
        const ValueKey('onyx-agent-action-refined-draft-open-comms'),
      );
      await tester.scrollUntilVisible(
        reopenCommsAction,
        220,
        scrollable: messageListScrollable,
      );
      final reopenCommsButton = tester.widget<OutlinedButton>(
        reopenCommsAction,
      );
      expect(reopenCommsButton.onPressed, isNotNull);
      reopenCommsButton.onPressed!.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey('clients-simple-queue-board')),
        findsOneWidget,
      );
      expect(find.byType(ClientsPage), findsOneWidget);
      expect(find.text('Client Communications'), findsWidgets);
      expect(find.text('INC-CLIENT-AGENT-101'), findsOneWidget);
      expect(find.text('FOCUSED DRAFT'), findsOneWidget);
      expect(find.text('RESUME DRAFT RAIL'), findsOneWidget);
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).clientId,
        'CLIENT-DEMO',
      );
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).siteId,
        'SITE-DEMO',
      );
      expect(
        find.byKey(const ValueKey('clients-open-agent-INC-CLIENT-AGENT-101')),
        findsOneWidget,
      );

      Future<void> reopenDetailedWorkspace() async {
        await _openClientsDetailedWorkspaceIfPresent(tester);
        expect(find.text('Open queued draft'), findsWidgets);
      }

      Future<void> assertQueuedDraftReturn(Key key) async {
        await reopenDetailedWorkspace();
        final action = find.byKey(key);
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('clients-simple-queue-board')),
          findsOneWidget,
        );
        expect(find.text('FOCUSED DRAFT'), findsOneWidget);
      }

      await assertQueuedDraftReturn(
        const ValueKey('clients-thread-review-queued-draft'),
      );
      expect(find.text('RESUME THREAD CONTEXT'), findsOneWidget);
      await assertQueuedDraftReturn(
        const ValueKey('clients-channel-review-queued-draft'),
      );
      expect(find.text('RESUME CHANNEL REVIEW'), findsOneWidget);
      await assertQueuedDraftReturn(
        const ValueKey('clients-review-drafts-action'),
      );
      expect(find.text('RESUME DRAFT RAIL'), findsOneWidget);

      final dynamicResumeAction = find.byWidgetPredicate(
        (widget) =>
            widget is ElevatedButton &&
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith(
              'clients-resume-detailed-workspace-agent-client-draft-',
            ),
      );
      expect(dynamicResumeAction, findsOneWidget);
      await tester.ensureVisible(dynamicResumeAction);
      await tester.tap(dynamicResumeAction);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clients-workspace-panel-board')),
        findsOneWidget,
      );
      expect(find.byType(ClientsPage), findsOneWidget);
      expect(find.text('Open queued draft'), findsWidgets);
      expect(
        find.byKey(const ValueKey('clients-thread-review-queued-draft')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('clients-channel-review-queued-draft')),
        findsOneWidget,
      );
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).clientId,
        'CLIENT-DEMO',
      );
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).siteId,
        'SITE-DEMO',
      );

      SharedPreferences.setMockInitialValues({});
      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 906,
          messageThreadId: 88,
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          sourceText: 'Please update me on the patrol position.',
          originalDraftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
          draftText:
              'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
          providerLabel: 'openai:gpt-4.1-mini',
          createdAtUtc: _clientsRouteOccurredAtUtc(51),
        ),
      ]);
      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-command-only-pending-draft-app'),
      );

      expect(find.text('CLIENT ASKED'), findsNothing);
      expect(find.text('ONYX WILL SAY'), findsNothing);
      expect(find.text('Awaiting human sign-off'), findsNothing);
      expect(find.text('Pending ONYX Draft'), findsNothing);
    },
  );

  testWidgets(
    'onyx app mirrors critical live telegram follow-up replies into control view without mirroring routine quick actions',
    (tester) async {
      final routineBridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('clients-routine-telegram-quick-action-app'),
        prompt: 'Check cameras',
        updateId: 907,
      );
      final routineReply = routineBridge.sentMessages.last.text;

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-routine-telegram-quick-action-control'),
      );

      expect(find.textContaining(routineReply), findsNothing);
      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-routine-telegram-quick-action-comms'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'SITE-DEMO',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('clients-latest-sent-follow-up-card')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('clients-latest-sent-follow-up-prepare-reply'),
        ),
        findsNothing,
      );

      final criticalCases =
          <
            ({
              Key routeKey,
              Key controlKey,
              List<String> prompts,
              int firstUpdateId,
              String expectedReply,
              String expectedAiPreparedDraft,
              bool? telegramAiAssistantEnabledOverride,
              bool? telegramAiApprovalRequiredOverride,
            })
          >[
            (
              routeKey: const ValueKey(
                'clients-critical-telegram-ai-route-app',
              ),
              controlKey: const ValueKey(
                'clients-critical-telegram-ai-control-app',
              ),
              prompts: const <String>[
                'Yes can someone check and let me know if everything is okay please',
                'Front gate',
              ],
              firstUpdateId: 910,
              expectedReply:
                  'We are checking access at MS Vallee Residence now. I will update you here with the next confirmed step.',
              expectedAiPreparedDraft:
                  'Control is checking the front gate at MS Vallee Residence now. I will confirm here as soon as security verifies everything is okay.',
              telegramAiAssistantEnabledOverride: true,
              telegramAiApprovalRequiredOverride: false,
            ),
            (
              routeKey: const ValueKey(
                'clients-critical-telegram-onyx-command-route-app',
              ),
              controlKey: const ValueKey(
                'clients-critical-telegram-onyx-command-control-app',
              ),
              prompts: const <String>[
                'pls check front gate',
                'send someone there',
              ],
              firstUpdateId: 920,
              expectedReply:
                  'I do not have a fresh verified event tied to Front Gate right now.',
              expectedAiPreparedDraft:
                  'Control is checking the front gate at MS Vallee Residence now. I will confirm here as soon as security verifies everything is okay.',
              telegramAiAssistantEnabledOverride: true,
              telegramAiApprovalRequiredOverride: null,
            ),
          ];

      for (final scenario in criticalCases) {
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: scenario.routeKey,
          prompts: scenario.prompts,
          firstUpdateId: scenario.firstUpdateId,
          telegramAiAssistantServiceOverride:
              const _ScriptedTelegramAiAssistantStub(),
          telegramAiAssistantEnabledOverride:
              scenario.telegramAiAssistantEnabledOverride,
          telegramAiApprovalRequiredOverride:
              scenario.telegramAiApprovalRequiredOverride,
        );

        expect(transcript, contains(scenario.expectedReply));

        await pumpClientControlSourceApp(
          tester,
          key: scenario.controlKey,
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
        );

        expect(
          find.text('Security Desk Console — CLIENT-DEMO / SITE-DEMO'),
          findsOneWidget,
        );
        final controlBridge = _RecordingTelegramBridgeStub();
        await tester.pumpWidget(
          OnyxApp(
            key: ValueKey('${scenario.routeKey}-comms'),
            supabaseReady: false,
            initialRouteOverride: OnyxRoute.clients,
            initialClientLaneClientIdOverride: 'CLIENT-DEMO',
            initialClientLaneSiteIdOverride: 'SITE-DEMO',
            telegramBridgeServiceOverride: controlBridge,
            telegramChatIdOverride: 'test-client-chat',
            telegramAiAssistantServiceOverride:
                const _ScriptedTelegramAiAssistantStub(),
            telegramAiAssistantEnabledOverride: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('clients-latest-sent-follow-up-card')),
          findsOneWidget,
        );
        expect(find.text('LATEST SENT FOLLOW-UP'), findsOneWidget);
        expect(find.text('HIGH PRIORITY'), findsOneWidget);
        expect(
          find.textContaining('Control reply recommended now'),
          findsOneWidget,
        );
        final prepareReplyAction = find.byKey(
          const ValueKey('clients-latest-sent-follow-up-prepare-reply'),
        );
        expect(prepareReplyAction, findsOneWidget);
        await tester.ensureVisible(prepareReplyAction);
        await tester.tap(prepareReplyAction);
        await tester.pumpAndSettle();
        expect(find.text('Edit Draft'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          scenario.expectedAiPreparedDraft,
        );
        await tester.enterText(
          find.byType(TextField),
          'Control confirms that everything is good.',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('clients-simple-queue-board')),
          findsOneWidget,
        );
        expect(find.text('FOCUSED DRAFT'), findsOneWidget);
        expect(find.text('RESUME DRAFT RAIL'), findsOneWidget);
        expect(find.text('SEND'), findsWidgets);
        final sendFocusedDraftAction = find.byWidgetPredicate(
          (widget) =>
              widget is ElevatedButton &&
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'clients-send-draft-live-follow-up-',
              ),
        );
        expect(sendFocusedDraftAction, findsOneWidget);
        await tester.ensureVisible(sendFocusedDraftAction);
        await tester.tap(sendFocusedDraftAction);
        await tester.pumpAndSettle();
        expect(
          controlBridge.sentMessages.map((message) => message.text).join('\n'),
          contains('Control confirms that everything is good.'),
        );
        expect(
          find.byKey(const ValueKey('clients-latest-sent-follow-up-card')),
          findsNothing,
        );
        expect(find.text('FOCUSED DRAFT'), findsNothing);
      }
    },
  );

  testWidgets(
    'onyx app sends focused client follow-ups through the correct telegram lane for the selected scope',
    (tester) async {
      final cases =
          <
            ({
              Key routeKey,
              Key controlKey,
              Key commsKey,
              int firstUpdateId,
              List<ClientTelegramEndpointRecord> records,
              String expectedChatId,
            })
          >[
            (
              routeKey: const ValueKey(
                'clients-followup-send-scoped-client-lane-route-app',
              ),
              controlKey: const ValueKey(
                'clients-followup-send-scoped-client-lane-control-app',
              ),
              commsKey: const ValueKey(
                'clients-followup-send-scoped-client-lane-comms-app',
              ),
              firstUpdateId: 961,
              records: const <ClientTelegramEndpointRecord>[
                ClientTelegramEndpointRecord(
                  endpointId: 'global-client-lane',
                  displayLabel: 'Client Telegram',
                  chatId: 'global-client-chat',
                ),
                ClientTelegramEndpointRecord(
                  endpointId: 'scoped-client-lane',
                  displayLabel: 'Client Telegram • Site',
                  chatId: 'scoped-client-chat',
                  siteId: 'SITE-DEMO',
                ),
                ClientTelegramEndpointRecord(
                  endpointId: 'scoped-partner-lane',
                  displayLabel: 'PARTNER • Response',
                  chatId: 'partner-chat',
                  siteId: 'SITE-DEMO',
                ),
              ],
              expectedChatId: 'scoped-client-chat',
            ),
            (
              routeKey: const ValueKey(
                'clients-followup-send-global-client-fallback-route-app',
              ),
              controlKey: const ValueKey(
                'clients-followup-send-global-client-fallback-control-app',
              ),
              commsKey: const ValueKey(
                'clients-followup-send-global-client-fallback-comms-app',
              ),
              firstUpdateId: 971,
              records: const <ClientTelegramEndpointRecord>[
                ClientTelegramEndpointRecord(
                  endpointId: 'global-client-lane',
                  displayLabel: 'Client Telegram',
                  chatId: 'global-client-chat',
                ),
                ClientTelegramEndpointRecord(
                  endpointId: 'scoped-partner-lane',
                  displayLabel: 'PARTNER • Response',
                  chatId: 'partner-chat',
                  siteId: 'SITE-DEMO',
                ),
              ],
              expectedChatId: 'global-client-chat',
            ),
          ];

      for (final scenario in cases) {
        await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: scenario.routeKey,
          prompts: const <String>[
            'Yes can someone check and let me know if everything is okay please',
            'Front gate',
          ],
          firstUpdateId: scenario.firstUpdateId,
          telegramAiAssistantServiceOverride:
              const _ScriptedTelegramAiAssistantStub(),
          telegramAiAssistantEnabledOverride: true,
          telegramAiApprovalRequiredOverride: false,
        );

        await pumpClientControlSourceApp(
          tester,
          key: scenario.controlKey,
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
        );

        final controlBridge = _RecordingTelegramBridgeStub();
        await tester.pumpWidget(
          OnyxApp(
            key: scenario.commsKey,
            supabaseReady: false,
            initialRouteOverride: OnyxRoute.clients,
            initialClientLaneClientIdOverride: 'CLIENT-DEMO',
            initialClientLaneSiteIdOverride: 'SITE-DEMO',
            telegramBridgeServiceOverride: controlBridge,
            telegramAiAssistantServiceOverride:
                const _ScriptedTelegramAiAssistantStub(),
            telegramAiAssistantEnabledOverride: true,
            managedTelegramEndpointRecordsResolverOverride:
                (clientId, siteId) async => scenario.records,
          ),
        );
        await tester.pumpAndSettle();

        final baselineMessageCount = controlBridge.sentMessages.length;
        final prepareReplyAction = find.byKey(
          const ValueKey('clients-latest-sent-follow-up-prepare-reply'),
        );
        expect(prepareReplyAction, findsOneWidget);
        await tester.ensureVisible(prepareReplyAction);
        await tester.tap(prepareReplyAction);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Control confirms that everything is good.',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final sendFocusedDraftAction = find.byWidgetPredicate(
          (widget) =>
              widget is ElevatedButton &&
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'clients-send-draft-live-follow-up-',
              ),
        );
        expect(sendFocusedDraftAction, findsOneWidget);
        await tester.ensureVisible(sendFocusedDraftAction);
        await tester.tap(sendFocusedDraftAction);
        await tester.pumpAndSettle();

        final sentReplyMessages = controlBridge.sentMessages
            .skip(baselineMessageCount)
            .where(
              (message) => message.text.contains(
                'Control confirms that everything is good.',
              ),
            )
            .toList(growable: false);
        expect(sentReplyMessages, hasLength(1));
        expect(sentReplyMessages.single.chatId, scenario.expectedChatId);
        expect(sentReplyMessages.single.messageThreadId, isNull);
      }
    },
  );

  testWidgets(
    'onyx app AI assist refines the operator draft instead of replacing it with a generic live-follow-up line',
    (tester) async {
      final transcript = await sendClientTelegramConversationThroughRoute(
        tester,
        appKey: const ValueKey('clients-draft-refine-telegram-route-app'),
        prompts: const <String>[
          'Yes can someone check and let me know if everything is okay please',
          'Front gate',
        ],
        firstUpdateId: 960,
        telegramAiAssistantServiceOverride:
            const _DraftRefiningTelegramAiAssistantStub(),
        telegramAiAssistantEnabledOverride: true,
        telegramAiApprovalRequiredOverride: false,
      );

      expect(
        transcript,
        contains(
          'We are checking access at MS Vallee Residence now. I will update you here with the next confirmed step.',
        ),
      );

      final controlBridge = _RecordingTelegramBridgeStub();
      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-draft-refine-telegram-comms'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'SITE-DEMO',
          telegramBridgeServiceOverride: controlBridge,
          telegramChatIdOverride: 'test-client-chat',
          telegramAiAssistantServiceOverride:
              const _DraftRefiningTelegramAiAssistantStub(),
          telegramAiAssistantEnabledOverride: true,
        ),
      );
      await tester.pumpAndSettle();

      final prepareReplyAction = find.byKey(
        const ValueKey('clients-latest-sent-follow-up-prepare-reply'),
      );
      expect(prepareReplyAction, findsOneWidget);
      await tester.ensureVisible(prepareReplyAction);
      await tester.tap(prepareReplyAction);
      await tester.pumpAndSettle();

      expect(find.text('Edit Draft'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'We currently do not have access to remote monitoring. Please advise if everything is good or would you like us to send a unit over?',
      );

      final aiAssistAction = find.byKey(
        const ValueKey('clients-edit-draft-ai-assist'),
      );
      expect(aiAssistAction, findsOneWidget);
      await tester.tap(aiAssistAction);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'We currently do not have access to remote monitoring, so I cannot confirm visually from here. If everything looks fine on your side, please let us know, or tell us if you want us to send a unit over.',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isNot(
          contains(
            'We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
          ),
        ),
      );
    },
  );

  testWidgets(
    'onyx app keeps the deterministic client quick-action and read matrix stable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cases =
          <
            ({
              String prompt,
              List<String> expected,
              List<String> excluded,
              int updateId,
              DateTime sentAtUtc,
            })
          >[
            (
              prompt: 'Details',
              expected: const <String>[
                'Site Demo is ',
                'Items reviewed:',
                'Latest signal:',
                'Remote watch is unavailable.',
                'Review note:',
                'Assessment: routine on-site team activity is visible',
              ],
              excluded: const <String>[],
              updateId: 9001,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 35),
            ),
            (
              prompt: 'Check cameras',
              expected: const <String>[
                'Live camera visibility at Site Demo is ',
                'Next step:',
              ],
              excluded: const <String>[],
              updateId: 90201,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 51),
            ),
            (
              prompt: 'Review cameras',
              expected: const <String>[
                'Live camera visibility at Site Demo is ',
                'Next step:',
              ],
              excluded: const <String>[],
              updateId: 9012,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 44),
            ),
            (
              prompt: 'Give me a quick update',
              expected: const <String>[
                'Remote monitoring is unavailable at Site Demo right now.',
                'nothing here confirms an issue on site',
              ],
              excluded: const <String>[
                'Items reviewed:',
                'Current posture:',
                'Open follow-ups:',
              ],
              updateId: 90202,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 52),
            ),
            (
              prompt: 'What is going on there',
              expected: const <String>[
                'Remote monitoring is unavailable at Site Demo right now.',
                'nothing here confirms an issue on site',
              ],
              excluded: const <String>[
                'Items reviewed:',
                'Current posture:',
                'Open follow-ups:',
              ],
              updateId: 90132,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 47),
            ),
            (
              prompt: 'Is my site secure?',
              expected: const <String>[
                'Remote monitoring is unavailable at Site Demo right now.',
                'nothing here confirms an issue on site',
              ],
              excluded: const <String>[
                'already escalated',
                'Items reviewed:',
                'Current posture:',
                'Open follow-ups:',
              ],
              updateId: 901321,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 47),
            ),
            (
              prompt: "What's happening on site?",
              expected: const <String>[
                'Remote monitoring is unavailable at Site Demo right now.',
                'nothing here confirms an issue on site',
              ],
              excluded: const <String>[
                'already on site',
                'Items reviewed:',
                'Current posture:',
                'Open follow-ups:',
              ],
              updateId: 9013211,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 47),
            ),
            (
              prompt: 'site stauts',
              expected: const <String>[
                'Remote monitoring is unavailable at Site Demo right now.',
                'nothing here confirms an issue on site',
              ],
              excluded: const <String>[
                'already on site',
                'Items reviewed:',
                'Current posture:',
                'Open follow-ups:',
              ],
              updateId: 901322,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 48),
            ),
            (
              prompt: 'What changed here',
              expected: const <String>[
                'Site Demo is ',
                'Remote watch is unavailable.',
                'Review note:',
                'Current decision:',
              ],
              excluded: const <String>[],
              updateId: 90203,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 53),
            ),
            (
              prompt: 'Anything new there',
              expected: const <String>[
                'Site Demo is ',
                'Remote watch is unavailable.',
                'Review note:',
                'Current decision:',
              ],
              excluded: const <String>[],
              updateId: 90204,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 54),
            ),
            (
              prompt: 'Just update me',
              expected: const <String>[
                'Remote monitoring is unavailable at Site Demo right now.',
                'nothing here confirms an issue on site',
              ],
              excluded: const <String>[
                'Items reviewed:',
                'Current posture:',
                'Open follow-ups:',
              ],
              updateId: 90135,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 50),
            ),
            (
              prompt: 'What changed since earlier',
              expected: const <String>[
                'Site Demo is ',
                'Remote watch is unavailable.',
                'Review note:',
                'Current decision:',
              ],
              excluded: const <String>[],
              updateId: 90131,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 47),
            ),
            (
              prompt: 'Check tonights breaches',
              expected: const <String>['• Window: 18:00-06:00'],
              excluded: const <String>[],
              updateId: 90205,
              sentAtUtc: _clientsQuickActionSentAtUtc(6, 55),
            ),
          ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final bridge = await pumpClientTelegramPromptThroughRoute(
          tester,
          appKey: ValueKey('clients-telegram-matrix-app-$index'),
          prompt: scenario.prompt,
          updateId: scenario.updateId,
          sentAtUtc: scenario.sentAtUtc,
        );

        final sentTranscript = bridge.sentMessages
            .map((message) => message.text)
            .join('\n---\n');
        for (final text in scenario.expected) {
          expect(sentTranscript, contains(text), reason: scenario.prompt);
        }
        for (final text in scenario.excluded) {
          expect(
            sentTranscript,
            isNot(contains(text)),
            reason: scenario.prompt,
          );
        }
        expect(
          sentTranscript,
          isNot(
            contains(
              'Understood. This has been escalated to the control room now.',
            ),
          ),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets('onyx app keeps the messy client conversational matrix stable', (
    tester,
  ) async {
    final now = _clientsMatrixNowUtc();

    List<DispatchEvent> buildVerificationEvents() => <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'client-route-verify-intel-1',
        sequence: 1,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 6)),
        intelligenceId: 'INT-ROUTE-CV-1',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'evt-route-cv-1',
        clientId: 'CLIENT-DEMO',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-DEMO',
        zone: 'Front Gate',
        headline: 'Front gate alert',
        summary: 'Person detected near the front gate.',
        riskScore: 68,
        canonicalHash: 'hash-route-cv-1',
      ),
    ];

    List<DispatchEvent> buildAlarmEvents() => <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'client-route-serious-intel-1',
        sequence: 1,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 11)),
        intelligenceId: 'INT-ROUTE-CA-1',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'evt-route-ca-1',
        clientId: 'CLIENT-DEMO',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-DEMO',
        headline: 'Perimeter breach alert',
        summary: 'Repeated movement triggered the perimeter alarm.',
        riskScore: 84,
        canonicalHash: 'hash-route-ca-1',
      ),
      DecisionCreated(
        eventId: 'client-route-serious-decision-1',
        sequence: 2,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 10)),
        dispatchId: 'DSP-ROUTE-CA-1',
        clientId: 'CLIENT-DEMO',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-DEMO',
      ),
    ];

    final cases =
        <
          ({
            String prompt,
            List<DispatchEvent> events,
            List<String> expected,
            List<String> excluded,
          })
        >[
          (
            prompt: 'whatst happednin at the siter',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'Remote monitoring is unavailable at Site Demo right now.',
              'nothing here confirms an issue on site',
            ],
            excluded: const <String>[
              'Unsupported command',
              'Your message has been received',
              'Items reviewed:',
              'Current posture:',
              'Open follow-ups:',
            ],
          ),
          (
            prompt: 'anyting rong there',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'Remote monitoring is unavailable at Site Demo right now.',
              'nothing here confirms an issue on site',
            ],
            excluded: const <String>[
              'Invalid input',
              'Unsupported command',
              'Items reviewed:',
              'Current posture:',
              'Open follow-ups:',
            ],
          ),
          (
            prompt: 'cn u chek frnt gte',
            events: buildVerificationEvents(),
            expected: const <String>[
              'The latest verified activity near Front Gate was',
              'I do not have live visual confirmation on Front Gate',
            ],
            excluded: const <String>['appears closed'],
          ),
          (
            prompt: 'was tht alrm serious',
            events: buildAlarmEvents(),
            expected: const <String>[
              'Response is still active.',
              'The latest confirmed alert was',
            ],
            excluded: const <String>['Unsupported command'],
          ),
          (
            prompt: 'I heard something outside',
            events: const <DispatchEvent>[],
            expected: const <String>[
              "I'm treating that as a live concern.",
              'I do not see a confirmed active incident in the current operational picture.',
              'I do not have live visual confirmation right now.',
              'I can have the outside area verified immediately.',
            ],
            excluded: const <String>['Unsupported command'],
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: ValueKey('clients-telegram-messy-conversation-app-$index'),
        prompt: scenario.prompt,
        updateId: 90136 + index,
        sentAtUtc: _clientsQuickActionSentAtUtc(6, 56 + index),
        initialStoreEventsOverride: scenario.events,
      );

      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n---\n');
      for (final text in scenario.expected) {
        expect(sentTranscript, contains(text), reason: scenario.prompt);
      }
      for (final text in scenario.excluded) {
        expect(sentTranscript, isNot(contains(text)), reason: scenario.prompt);
      }
    }
  });

  testWidgets('onyx app keeps the soft action language matrix stable', (
    tester,
  ) async {
    final now = _clientsMatrixNowUtc();
    final activeAreaEvents = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'route-client-action-open-intel-1',
        sequence: 1,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 11)),
        intelligenceId: 'INT-ROUTE-CLIENT-ACTION-OPEN-1',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'evt-route-client-action-open-1',
        clientId: 'CLIENT-DEMO',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-DEMO',
        zone: 'Front Gate',
        headline: 'Front gate movement alert',
        summary: 'Repeated movement near the front gate triggered review.',
        riskScore: 74,
        canonicalHash: 'hash-route-client-action-open-1',
      ),
      DecisionCreated(
        eventId: 'route-client-action-open-decision-1',
        sequence: 2,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 8)),
        dispatchId: 'DSP-ROUTE-CLIENT-ACTION-OPEN-1',
        clientId: 'CLIENT-DEMO',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-DEMO',
      ),
    ];

    final cases =
        <
          ({
            String prompt,
            List<DispatchEvent> events,
            List<String> expected,
            List<String> excluded,
          })
        >[
          (
            prompt: 'pls send someone to frnt gte',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'I do not see a fresh verified event tied to Front Gate right now.',
              'I have not initiated a dispatch from this message alone',
              'I can prioritise Front Gate for immediate verification.',
              'I do not have live visual confirmation on Front Gate',
            ],
            excluded: const <String>[],
          ),
          (
            prompt: 'have someone check the perimeter side',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'I do not see a fresh verified event tied to Perimeter right now.',
              'I have not initiated a dispatch from this message alone',
              'I can prioritise Perimeter for immediate verification.',
              'I do not have live visual confirmation on Perimeter',
            ],
            excluded: const <String>[],
          ),
          (
            prompt: 'pls snd smone',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'I’m not fully certain which area you want actioned first.',
              'If you tell me which gate, entrance, or perimeter point matters most',
            ],
            excluded: const <String>[],
          ),
          (
            prompt: 'can a gaurd chek',
            events: const <DispatchEvent>[],
            expected: const <String>[
              'I’m not fully certain which area you want actioned first.',
              'If you tell me which gate, entrance, or perimeter point matters most',
            ],
            excluded: const <String>[],
          ),
          (
            prompt: 'pls send someone to frnt gte',
            events: activeAreaEvents,
            expected: const <String>[
              'There is already an active operational response around Front Gate.',
              'I have not initiated a second dispatch from this message alone.',
            ],
            excluded: const <String>[
              'I can prioritise Front Gate for immediate verification.',
            ],
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: ValueKey('clients-telegram-soft-action-matrix-app-$index'),
        prompt: scenario.prompt,
        updateId: 90141 + index,
        sentAtUtc: _clientsQuickActionSentAtUtc(7, 1 + index),
        initialStoreEventsOverride: scenario.events,
      );

      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n---\n');
      for (final text in scenario.expected) {
        expect(sentTranscript, contains(text), reason: scenario.prompt);
      }
      for (final text in scenario.excluded) {
        expect(sentTranscript, isNot(contains(text)), reason: scenario.prompt);
      }
      expect(
        sentTranscript,
        isNot(contains('Unsupported command')),
        reason: scenario.prompt,
      );
    }
  });

  testWidgets('onyx app keeps the early thread-context carryover matrix stable', (
    tester,
  ) async {
    final now = _clientsMatrixNowUtc();
    final sameGateIncidentEvents = <DispatchEvent>[
      IntelligenceReceived(
        eventId: 'route-same-gate-intel-1',
        sequence: 1,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 10)),
        intelligenceId: 'INT-ROUTE-SAME-GATE-1',
        provider: 'hikvision-dvr',
        sourceType: 'dvr',
        externalId: 'evt-route-same-gate-1',
        clientId: 'CLIENT-DEMO',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-DEMO',
        zone: 'Front Gate',
        headline: 'Front gate motion alert',
        summary: 'Repeated movement triggered review at the front gate.',
        riskScore: 79,
        canonicalHash: 'hash-route-same-gate-1',
      ),
      DecisionCreated(
        eventId: 'route-same-gate-decision-1',
        sequence: 2,
        version: 1,
        occurredAt: now.subtract(const Duration(minutes: 8)),
        dispatchId: 'DSP-ROUTE-SAME-GATE-1',
        clientId: 'CLIENT-DEMO',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-DEMO',
      ),
    ];

    final cases =
        <
          ({
            List<String> prompts,
            int updateId,
            List<DispatchEvent> events,
            String expectedLead,
            String? expectedFollowUp,
            String expectedVisualArea,
          })
        >[
          (
            prompts: const <String>[
              'pls check front gate',
              'check the same gate again',
            ],
            updateId: 90144,
            events: const <DispatchEvent>[],
            expectedLead:
                'I do not have a fresh verified event tied to Front Gate right now',
            expectedFollowUp: null,
            expectedVisualArea: 'Front Gate',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'was that the same gate as before?',
            ],
            updateId: 90146,
            events: sameGateIncidentEvents,
            expectedLead: 'The latest confirmed alert points to Gate again.',
            expectedFollowUp: 'Response is still active.',
            expectedVisualArea: 'Gate',
          ),
          (
            prompts: const <String>[
              'pls check front gate',
              'send someone there',
            ],
            updateId: 90148,
            events: const <DispatchEvent>[],
            expectedLead:
                'I do not have a fresh verified event tied to Front Gate right now.',
            expectedFollowUp: 'prioritise that for the next verified check.',
            expectedVisualArea: 'Front Gate',
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final transcript = await sendClientTelegramConversationThroughRoute(
        tester,
        appKey: ValueKey(
          'clients-telegram-thread-context-carryover-matrix-app-$index',
        ),
        prompts: scenario.prompts,
        firstUpdateId: scenario.updateId,
        initialStoreEventsOverride: scenario.events,
      );

      expect(
        transcript,
        contains(scenario.expectedLead),
        reason: scenario.prompts.last,
      );
      if (scenario.expectedFollowUp case final expectedFollowUp?) {
        expect(
          transcript,
          contains(expectedFollowUp),
          reason: scenario.prompts.last,
        );
      }
      expect(
        transcript,
        contains(
          'I do not have live visual confirmation on ${scenario.expectedVisualArea}',
        ),
        reason: scenario.prompts.last,
      );
      expect(
        transcript,
        isNot(contains('Unsupported command')),
        reason: scenario.prompts.last,
      );
    }
  });

  testWidgets(
    'onyx app keeps the premium camera carryover reassurance matrix stable',
    (tester) async {
      IntelligenceReceived buildCameraEvent({
        required int index,
        required String area,
      }) {
        final lowerArea = area.toLowerCase();
        return IntelligenceReceived(
          eventId: 'route-premium-camera-matrix-intel-${index + 1}',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 4, 2, 19, 18 + index),
          intelligenceId: 'INT-ROUTE-PREMIUM-CAMERA-MATRIX-${index + 1}',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-route-premium-camera-matrix-${index + 1}',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: area,
          headline: '$lowerArea motion alert',
          summary: 'Movement at the $lowerArea triggered review.',
          riskScore: 61,
          canonicalHash: 'hash-route-premium-camera-matrix-${index + 1}',
        );
      }

      final cases =
          <
            ({
              String prompt,
              String leadingPrompt,
              String expectedArea,
              int updateId,
            })
          >[
            for (final prompt in const <String>[
              'is it safe at the same camera now?',
              'is it all clear at the same camera now?',
              'is it calm at the same camera now?',
              'is it caln at the same camra now?',
            ])
              (
                prompt: prompt,
                leadingPrompt: 'what happened at the back camera?',
                expectedArea: 'Back Camera',
                updateId:
                    90372 +
                    const <String>[
                      'is it safe at the same camera now?',
                      'is it all clear at the same camera now?',
                      'is it calm at the same camera now?',
                      'is it caln at the same camra now?',
                    ].indexOf(prompt),
              ),
            (
              prompt: 'is it saef at the sme camra now?',
              leadingPrompt: 'what happened at the back camera?',
              expectedArea: 'Back Camera',
              updateId: 90358,
            ),
            for (final prompt in const <String>[
              'is it clear at the same cctv then?',
              'is it quiet at the same cctv then?',
              'has it stayed calm at the same cctv?',
              'has it staid calm at the same cctvv?',
            ])
              (
                prompt: prompt,
                leadingPrompt: 'what happened at the back cctv?',
                expectedArea: 'Back Cctv',
                updateId:
                    90376 +
                    const <String>[
                      'is it clear at the same cctv then?',
                      'is it quiet at the same cctv then?',
                      'has it stayed calm at the same cctv?',
                      'has it staid calm at the same cctvv?',
                    ].indexOf(prompt),
              ),
            (
              prompt: 'is it cleer at the sme cctvv then?',
              leadingPrompt: 'what happened at the back cctv?',
              expectedArea: 'Back Cctv',
              updateId: 90359,
            ),
          ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey('clients-telegram-premium-camera-matrix-app-$index'),
          prompts: <String>[scenario.leadingPrompt, scenario.prompt],
          firstUpdateId: scenario.updateId,
          initialStoreEventsOverride: <DispatchEvent>[
            buildCameraEvent(index: index, area: scenario.expectedArea),
          ],
        );

        expect(
          transcript,
          contains('The latest verified activity near'),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          predicate<String>(
            (value) =>
                value.contains('I do not have live visual confirmation') ||
                _hasGenericAreaAmbiguity(value),
            'contains a visual confirmation gap or generic area ambiguity',
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('Unsupported command')),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets(
    'onyx app keeps the premium camera carryover ambiguity matrix stable',
    (tester) async {
      final cases = <({String prompt, String expectedType, int updateId})>[
        for (final prompt in const <String>[
          'is it safe at the same camera now?',
          'is it all clear at the same camera now?',
          'is it calm at the same camera now?',
          'is it caln at the same camra now?',
        ])
          (
            prompt: prompt,
            expectedType: 'Camera',
            updateId:
                90380 +
                const <String>[
                  'is it safe at the same camera now?',
                  'is it all clear at the same camera now?',
                  'is it calm at the same camera now?',
                  'is it caln at the same camra now?',
                ].indexOf(prompt),
          ),
        (
          prompt: 'is it saef at the sme camra now?',
          expectedType: 'Camera',
          updateId: 90356,
        ),
        for (final prompt in const <String>[
          'is it clear at the same cctv then?',
          'is it quiet at the same cctv then?',
          'has it stayed calm at the same cctv?',
          'has it staid calm at the same cctvv?',
        ])
          (
            prompt: prompt,
            expectedType: 'Cctv',
            updateId:
                90384 +
                const <String>[
                  'is it clear at the same cctv then?',
                  'is it quiet at the same cctv then?',
                  'has it stayed calm at the same cctv?',
                  'has it staid calm at the same cctvv?',
                ].indexOf(prompt),
          ),
        (
          prompt: 'is it cleer at the sme cctvv then?',
          expectedType: 'Cctv',
          updateId: 90357,
        ),
      ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final leadingPrompts = scenario.expectedType == 'Camera'
            ? const <String>[
                'what happened at the front camera?',
                'what happened at the back camera?',
              ]
            : const <String>[
                'what happened at the front cctv?',
                'what happened at the back cctv?',
              ];
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey(
            'clients-telegram-premium-camera-ambiguity-matrix-app-$index',
          ),
          prompts: <String>[...leadingPrompts, scenario.prompt],
          firstUpdateId: scenario.updateId,
        );

        final expectedArea = scenario.expectedType == 'Camera'
            ? 'Back Camera'
            : 'Back Cctv';

        expect(
          transcript,
          contains(
            'I do not have a fresh verified event tied to $expectedArea right now.',
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          contains(
            'I do not have live visual confirmation on $expectedArea right now.',
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('I’m not fully certain whether you mean')),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('Unsupported command')),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets(
    'onyx app keeps the premium explicit area carryover reassurance matrix stable',
    (tester) async {
      IntelligenceReceived buildAreaEvent({
        required int index,
        required String area,
      }) {
        final lowerArea = area.toLowerCase();
        return IntelligenceReceived(
          eventId: 'route-premium-area-matrix-intel-${index + 1}',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 4, 2, 19, 22 + index),
          intelligenceId: 'INT-ROUTE-PREMIUM-AREA-MATRIX-${index + 1}',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-route-premium-area-matrix-${index + 1}',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: area,
          headline: '$lowerArea motion alert',
          summary: 'Movement at the $lowerArea triggered review.',
          riskScore: 61,
          canonicalHash: 'hash-route-premium-area-matrix-${index + 1}',
        );
      }

      final cases =
          <
            ({
              String prompt,
              String leadingPrompt,
              String expectedArea,
              bool seedsLatestActivity,
              bool expectsFreshVerifiedGap,
            })
          >[
            (
              prompt: 'is that entrance okay now?',
              leadingPrompt: 'pls check entrance',
              expectedArea: 'Entrance',
              seedsLatestActivity: false,
              expectsFreshVerifiedGap: true,
            ),
            for (final prompt in const <String>[
              'is it all clear at the same gate now?',
              'is it caln at the same gate now?',
            ])
              (
                prompt: prompt,
                leadingPrompt: 'what happened at the back gate?',
                expectedArea: 'Back Gate',
                seedsLatestActivity: true,
                expectsFreshVerifiedGap: false,
              ),
            for (final prompt in const <String>[
              'is the entrance side okay now?',
              'is it quiet at the same entrance then?',
              'has it staid calm at the same entrance?',
            ])
              (
                prompt: prompt,
                leadingPrompt: 'what happened at the back entrance?',
                expectedArea: 'Back Entrance',
                seedsLatestActivity: true,
                expectsFreshVerifiedGap: false,
              ),
            for (final prompt in const <String>[
              'is it still safe at the sme gate?',
              'is it okay at the sme gate now?',
              'is it oaky at the sme gate now?',
              'is it saef at the sme gate now?',
              'is it all clear at the sme gate now?',
              'is it all cleer at the sme gate now?',
              'is it quiet at the sme gate now?',
              'is it qiuet at the sme gate now?',
              'is it calm at the sme gate now?',
              'is it caln at the sme gate now?',
              'has it stayed calm at the sme gate?',
              'has it staid calm at the sme gate?',
            ])
              (
                prompt: prompt,
                leadingPrompt: 'what happened at the front gate?',
                expectedArea: 'Front Gate',
                seedsLatestActivity: true,
                expectsFreshVerifiedGap: false,
              ),
            for (final prompt in const <String>[
              'is it still clear at the sme entrance?',
              'is it okay at the sme entrance then?',
              'is it oaky at the sme entrance then?',
              'is it saef at the sme entrance then?',
              'is it all clear at the sme entrance then?',
              'is it all cleer at the sme entrance then?',
              'is it quiet at the sme entrance then?',
              'is it qiuet at the sme entrance then?',
              'is it calm at the sme entrance then?',
              'is it caln at the sme entrance then?',
              'has it stayed calm at the sme entrance?',
              'has it staid calm at the sme entrance?',
            ])
              (
                prompt: prompt,
                leadingPrompt: 'what happened at the back entrance?',
                expectedArea: 'Back Entrance',
                seedsLatestActivity: true,
                expectsFreshVerifiedGap: false,
              ),
          ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey('clients-telegram-premium-area-matrix-app-$index'),
          prompts: <String>[scenario.leadingPrompt, scenario.prompt],
          firstUpdateId: 90460 + index,
          initialStoreEventsOverride: scenario.seedsLatestActivity
              ? <DispatchEvent>[
                  buildAreaEvent(index: index, area: scenario.expectedArea),
                ]
              : const <DispatchEvent>[],
        );

        if (scenario.expectsFreshVerifiedGap) {
          expect(
            transcript,
            contains(
              'I do not have a fresh verified event tied to ${scenario.expectedArea} right now',
            ),
            reason: scenario.prompt,
          );
        }
        if (scenario.seedsLatestActivity) {
          expect(
            transcript,
            predicate<String>(
              (value) => _hasRecentActivityLead(value, scenario.expectedArea),
              'contains a recent-activity lead for ${scenario.expectedArea}',
            ),
            reason: scenario.prompt,
          );
        }
        expect(
          transcript,
          predicate<String>(
            (value) => _hasVisualGap(value, scenario.expectedArea),
            'contains a visual confirmation gap for ${scenario.expectedArea}',
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('Unsupported command')),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets(
    'onyx app keeps the premium explicit area carryover ambiguity matrix stable',
    (tester) async {
      final cases = <({String prompt, String expectedType, int updateId})>[
        (
          prompt: 'is it safe at the same gate now?',
          expectedType: 'Gate',
          updateId: 90350,
        ),
        (
          prompt: 'is it all clear at the same gate now?',
          expectedType: 'Gate',
          updateId: 90414,
        ),
        (
          prompt: 'is it caln at the same gate now?',
          expectedType: 'Gate',
          updateId: 90415,
        ),
        (
          prompt: 'is the entrance side okay now?',
          expectedType: 'Entrance',
          updateId: 90151,
        ),
        (
          prompt: 'is the entrance side still okay now?',
          expectedType: 'Entrance',
          updateId: 90152,
        ),
        (
          prompt: 'is tht side safe then?',
          expectedType: 'Entrance',
          updateId: 90288,
        ),
        (
          prompt: 'is tht side clear then?',
          expectedType: 'Entrance',
          updateId: 90289,
        ),
        (
          prompt: 'is it clear at the same entrance then?',
          expectedType: 'Entrance',
          updateId: 90351,
        ),
        (
          prompt: 'is it quiet at the same entrance then?',
          expectedType: 'Entrance',
          updateId: 90416,
        ),
        (
          prompt: 'has it staid calm at the same entrance?',
          expectedType: 'Entrance',
          updateId: 90417,
        ),
      ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final leadingPrompts = scenario.expectedType == 'Gate'
            ? const <String>[
                'what happened at the front gate?',
                'what happened at the back gate?',
              ]
            : const <String>[
                'what happened at the front entrance?',
                'what happened at the back entrance?',
              ];
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey(
            'clients-telegram-premium-area-ambiguity-matrix-app-$index',
          ),
          prompts: <String>[...leadingPrompts, scenario.prompt],
          firstUpdateId: scenario.updateId,
        );

        final expectedArea = scenario.expectedType == 'Gate'
            ? 'Back Gate'
            : 'Back Entrance';

        expect(
          transcript,
          contains(
            'I do not have a fresh verified event tied to $expectedArea right now.',
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          contains(
            'I do not have live visual confirmation on $expectedArea right now.',
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('I’m not fully certain whether you mean')),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('Unsupported command')),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets(
    'onyx app keeps the softer contextual carryover reassurance matrix stable',
    (tester) async {
      final cases =
          <
            ({
              List<String> leadingPrompts,
              String prompt,
              String expectedArea,
              DispatchEvent event,
              int updateId,
            })
          >[
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is tht side okay now?',
              expectedArea: 'Back Entrance',
              updateId: 90282,
              event: IntelligenceReceived(
                eventId: 'route-tht-side-okay-now-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-THT-SIDE-OKAY-NOW-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-tht-side-okay-now-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-tht-side-okay-now-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is tht side still okay then?',
              expectedArea: 'Back Entrance',
              updateId: 90284,
              event: IntelligenceReceived(
                eventId: 'route-tht-side-still-okay-then-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-THT-SIDE-STILL-OKAY-THEN-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-tht-side-still-okay-then-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-tht-side-still-okay-then-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is tht side safe then?',
              expectedArea: 'Back Entrance',
              updateId: 90286,
              event: IntelligenceReceived(
                eventId: 'route-tht-side-safe-then-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-THT-SIDE-SAFE-THEN-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-tht-side-safe-then-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-tht-side-safe-then-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is tht side clear then?',
              expectedArea: 'Back Entrance',
              updateId: 90287,
              event: IntelligenceReceived(
                eventId: 'route-tht-side-clear-then-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-THT-SIDE-CLEAR-THEN-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-tht-side-clear-then-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-tht-side-clear-then-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it safe ovr ther now?',
              expectedArea: 'Back Entrance',
              updateId: 90294,
              event: IntelligenceReceived(
                eventId: 'route-safe-ovr-ther-now-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-SAFE-OVR-THER-NOW-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-safe-ovr-ther-now-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-safe-ovr-ther-now-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it clear ovr ther now?',
              expectedArea: 'Back Entrance',
              updateId: 90295,
              event: IntelligenceReceived(
                eventId: 'route-clear-ovr-ther-now-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-CLEAR-OVR-THER-NOW-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-clear-ovr-ther-now-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-clear-ovr-ther-now-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it safe ovr ther then?',
              expectedArea: 'Back Entrance',
              updateId: 90292,
              event: IntelligenceReceived(
                eventId: 'route-safe-ovr-ther-then-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-SAFE-OVR-THER-THEN-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-safe-ovr-ther-then-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-safe-ovr-ther-then-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it clear ovr ther then?',
              expectedArea: 'Back Entrance',
              updateId: 90293,
              event: IntelligenceReceived(
                eventId: 'route-clear-ovr-ther-then-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-CLEAR-OVR-THER-THEN-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-clear-ovr-ther-then-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-clear-ovr-ther-then-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it still safe on the othr side?',
              expectedArea: 'Back Entrance',
              updateId: 90308,
              event: IntelligenceReceived(
                eventId: 'route-still-safe-on-othr-side-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-STILL-SAFE-ON-OTHR-SIDE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-still-safe-on-othr-side-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-still-safe-on-othr-side-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it still clear on the othr side?',
              expectedArea: 'Back Entrance',
              updateId: 90309,
              event: IntelligenceReceived(
                eventId: 'route-still-clear-on-othr-side-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-STILL-CLEAR-ON-OTHR-SIDE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-still-clear-on-othr-side-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-still-clear-on-othr-side-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it still safe on the othr one?',
              expectedArea: 'Back Entrance',
              updateId: 90312,
              event: IntelligenceReceived(
                eventId: 'route-still-safe-on-othr-one-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-STILL-SAFE-ON-OTHR-ONE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-still-safe-on-othr-one-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-still-safe-on-othr-one-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it still clear on the othr one?',
              expectedArea: 'Back Entrance',
              updateId: 90313,
              event: IntelligenceReceived(
                eventId: 'route-still-clear-on-othr-one-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-STILL-CLEAR-ON-OTHR-ONE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-still-clear-on-othr-one-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-still-clear-on-othr-one-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it still safe on tht one?',
              expectedArea: 'Back Entrance',
              updateId: 90316,
              event: IntelligenceReceived(
                eventId: 'route-still-safe-on-tht-one-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-STILL-SAFE-ON-THT-ONE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-still-safe-on-tht-one-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-still-safe-on-tht-one-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it still clear on tht one?',
              expectedArea: 'Back Entrance',
              updateId: 90317,
              event: IntelligenceReceived(
                eventId: 'route-still-clear-on-tht-one-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 14),
                intelligenceId: 'INT-ROUTE-STILL-CLEAR-ON-THT-ONE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-still-clear-on-tht-one-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-still-clear-on-tht-one-1',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it still clear ovr ther?',
              expectedArea: 'Back Entrance',
              updateId: 91051,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-2',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 27),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-2',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-2',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-2',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it still safe on tht side?',
              expectedArea: 'Back Entrance',
              updateId: 91052,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-3',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 28),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-3',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-3',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-3',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'what happened at the back entrance?',
              ],
              prompt: 'is it still clear on tht side?',
              expectedArea: 'Back Entrance',
              updateId: 91053,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-4',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 29),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-4',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-4',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-4',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'pls check front gate',
                'what happened at the back entrance?',
              ],
              prompt: 'is it still safe on the same one?',
              expectedArea: 'Back Entrance',
              updateId: 91054,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-5',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 30),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-5',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-5',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-5',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'pls check front gate',
                'what happened at the back entrance?',
              ],
              prompt: 'is it still clear on the same one?',
              expectedArea: 'Back Entrance',
              updateId: 91055,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-6',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 31),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-6',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-6',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-6',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'pls check front gate',
                'what happened at the back entrance?',
              ],
              prompt: 'is it still safe on the same side?',
              expectedArea: 'Back Entrance',
              updateId: 91056,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-7',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 32),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-7',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-7',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-7',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'pls check front gate',
                'what happened at the back entrance?',
              ],
              prompt: 'is it still clear on the same side?',
              expectedArea: 'Back Entrance',
              updateId: 91057,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-8',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 33),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-8',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-8',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-8',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'pls check front gate',
                'what happened at the back entrance?',
              ],
              prompt: 'is it still safe on the sme side?',
              expectedArea: 'Back Entrance',
              updateId: 91058,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-9',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 34),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-9',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-9',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-9',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'pls check front gate',
                'what happened at the back entrance?',
              ],
              prompt: 'is it still clear on the sme side?',
              expectedArea: 'Back Entrance',
              updateId: 91059,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-10',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 35),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-10',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-10',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-10',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'pls check front gate',
                'what happened at the back entrance?',
              ],
              prompt: 'is it still safe on the sme one?',
              expectedArea: 'Back Entrance',
              updateId: 91060,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-11',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 36),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-11',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-11',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-11',
              ),
            ),
            (
              leadingPrompts: const <String>[
                'pls check front gate',
                'what happened at the back entrance?',
              ],
              prompt: 'is it still clear on the sme one?',
              expectedArea: 'Back Entrance',
              updateId: 91061,
              event: IntelligenceReceived(
                eventId: 'route-contextual-matrix-intel-12',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 4, 2, 19, 37),
                intelligenceId: 'INT-ROUTE-CONTEXTUAL-MATRIX-12',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-matrix-12',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary: 'Movement at the back entrance triggered review.',
                riskScore: 61,
                canonicalHash: 'hash-route-contextual-matrix-12',
              ),
            ),
          ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey(
            'clients-telegram-contextual-carryover-matrix-app-$index',
          ),
          prompts: <String>[...scenario.leadingPrompts, scenario.prompt],
          firstUpdateId: scenario.updateId,
          minimumExpectedMessages: 2,
          initialStoreEventsOverride: <DispatchEvent>[scenario.event],
        );

        expect(
          transcript,
          contains(
            'The current operational picture does not show an open threat at this stage.',
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          predicate<String>(
            (value) =>
                value.contains('The latest verified activity near') ||
                value.contains('The latest confirmed alert was'),
            'contains a recent-activity summary',
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          predicate<String>(
            (value) =>
                value.contains('I do not have live visual confirmation') ||
                _hasGenericAreaAmbiguity(value),
            'contains a visual confirmation gap or generic area ambiguity',
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('Unsupported command')),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets(
    'onyx app keeps the softer contextual carryover ambiguity matrix stable',
    (tester) async {
      final cases = <({String prompt, int updateId})>[
        (prompt: 'is it safe ovr ther now?', updateId: 90296),
        (prompt: 'is it clear ovr ther now?', updateId: 90297),
        (prompt: 'is it safe ovr ther then?', updateId: 91054),
        (prompt: 'is it clear ovr ther then?', updateId: 90291),
        (prompt: 'is it still clear ovr ther?', updateId: 91055),
        (prompt: 'is it still safe on the othr side?', updateId: 90306),
        (prompt: 'is it still clear on the othr side?', updateId: 90307),
        (prompt: 'is it still safe on the othr one?', updateId: 90310),
        (prompt: 'is it still clear on the othr one?', updateId: 90311),
        (prompt: 'is it still safe on tht one?', updateId: 90314),
        (prompt: 'is it still safe on tht side?', updateId: 91056),
        (prompt: 'is it still clear on tht side?', updateId: 91057),
        (prompt: 'is it still clear on tht one?', updateId: 91058),
      ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey(
            'clients-telegram-contextual-carryover-ambiguity-matrix-app-$index',
          ),
          prompts: <String>[
            'pls check front gate',
            'pls check back entrance',
            scenario.prompt,
          ],
          firstUpdateId: scenario.updateId,
        );

        expect(
          transcript,
          _matchesLegacyAmbiguityOrEnumeratedAreaFallback(
            legacyPattern: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
            legacyFollowUps: const <String>[
              'If you tell me which one you want checked first, I’ll focus the next verified update there.',
            ],
            areas: const <String>['Front Gate', 'Back Entrance'],
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('Unsupported command')),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets('onyx app keeps the softer contextual presence-history matrix stable', (
    tester,
  ) async {
    final now = _clientsMatrixNowUtc();

    List<DispatchEvent> missingResponseHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 20)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 16)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
      ];
    }

    List<DispatchEvent> missingPatrolHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 20)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
      ];
    }

    List<DispatchEvent> responseArrivalHistory({
      required String prefix,
      required String zone,
      required String alertHeadline,
      required String alertSummary,
      required String arrivalSummary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        ...missingResponseHistory(
          prefix: prefix,
          zone: zone,
          headline: alertHeadline,
          summary: alertSummary,
          riskScore: riskScore,
        ),
        IntelligenceReceived(
          eventId: '$prefix-intel-2',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 8)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-2',
          provider: 'field-ops',
          sourceType: 'ops',
          externalId: 'evt-$prefix-2',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: 'Response arrival',
          summary: arrivalSummary,
          riskScore: 28,
          canonicalHash: 'hash-$prefix-2',
        ),
      ];
    }

    List<DispatchEvent> patrolHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        ...missingPatrolHistory(
          prefix: prefix,
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
        ),
        PatrolCompleted(
          eventId: '$prefix-patrol-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 11)),
          routeId: 'back-entrance-route',
          guardId: 'Guard014',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          durationSeconds: 420,
        ),
      ];
    }

    final cases =
        <
          ({
            List<String> prompts,
            List<DispatchEvent> events,
            String expectedArea,
            int updateId,
            bool expectsArrival,
          })
        >[
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'so still no one there after that then?',
            ],
            events: missingResponseHistory(
              prefix: 'route-contextual-presence-missing-perimeter',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91058,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'so still no one there then?',
            ],
            events: missingResponseHistory(
              prefix: 'route-contextual-presence-missing-still-there',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91070,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'so no one got there after that then?',
            ],
            events: missingResponseHistory(
              prefix: 'route-contextual-presence-missing-after-that',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91068,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'so no one got there yet then?',
            ],
            events: missingResponseHistory(
              prefix: 'route-contextual-presence-missing-yet',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91069,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did any1 get there since earlier or not yet?',
            ],
            events: missingResponseHistory(
              prefix:
                  'route-contextual-presence-missing-any1-get-since-earlier',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 90245,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did they get there yet?',
            ],
            events: missingResponseHistory(
              prefix:
                  'route-contextual-presence-missing-did-they-get-there-yet',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91078,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did anyone get to that side yet?',
            ],
            events: missingResponseHistory(
              prefix:
                  'route-contextual-presence-missing-did-anyone-get-that-side-yet',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91081,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did someone check that side yet?',
            ],
            events: missingPatrolHistory(
              prefix:
                  'route-contextual-presence-missing-did-someone-check-side-yet',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Perimeter',
            updateId: 91079,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so no one checked that side yet then?',
            ],
            events: missingPatrolHistory(
              prefix: 'route-contextual-presence-missing-check-yet',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91071,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so still no one checked that side then?',
            ],
            events: missingPatrolHistory(
              prefix: 'route-contextual-presence-missing-check-still',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91072,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so no one has checked that side since then?',
            ],
            events: missingPatrolHistory(
              prefix:
                  'route-contextual-presence-missing-has-checked-side-since-then',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91076,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'has any1 checked that side since then or still no?',
            ],
            events: missingPatrolHistory(
              prefix:
                  'route-contextual-presence-missing-any1-checked-side-since-then',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 90246,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so someone did check that side then?',
            ],
            events: patrolHistory(
              prefix: 'route-contextual-presence-patrol-did-check-side',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91073,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so someone has checked that side then?',
            ],
            events: patrolHistory(
              prefix: 'route-contextual-presence-patrol-has-checked-side',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91074,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'has any1 checked that side yet?',
            ],
            events: patrolHistory(
              prefix: 'route-contextual-presence-patrol-any1-checked-side-yet',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 90240,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so someone has checked that side since then?',
            ],
            events: patrolHistory(
              prefix:
                  'route-contextual-presence-patrol-has-checked-side-since-then',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91075,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'has any1 checked that side since then?',
            ],
            events: patrolHistory(
              prefix:
                  'route-contextual-presence-patrol-any1-checked-side-since-then',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 90243,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has someone looked there yet?',
            ],
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId:
                    'route-contextual-presence-patrol-looked-there-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 20)),
                intelligenceId:
                    'INT-ROUTE-CONTEXTUAL-PRESENCE-PATROL-LOOKED-THERE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId:
                    'evt-route-contextual-presence-patrol-looked-there-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
                canonicalHash:
                    'hash-route-contextual-presence-patrol-looked-there-1',
              ),
              PatrolCompleted(
                eventId:
                    'route-contextual-presence-patrol-looked-there-patrol-1',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 11)),
                routeId: 'perimeter-route',
                guardId: 'Guard011',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                durationSeconds: 420,
              ),
            ],
            expectedArea: 'Perimeter',
            updateId: 90235,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has any1 looked there yet?',
            ],
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId:
                    'route-contextual-presence-patrol-any1-looked-there-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 20)),
                intelligenceId:
                    'INT-ROUTE-CONTEXTUAL-PRESENCE-PATROL-ANY1-LOOKED-THERE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId:
                    'evt-route-contextual-presence-patrol-any1-looked-there-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
                canonicalHash:
                    'hash-route-contextual-presence-patrol-any1-looked-there-1',
              ),
              PatrolCompleted(
                eventId:
                    'route-contextual-presence-patrol-any1-looked-there-patrol-1',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 11)),
                routeId: 'perimeter-route',
                guardId: 'Guard011',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                durationSeconds: 420,
              ),
            ],
            expectedArea: 'Perimeter',
            updateId: 90237,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did sm1 check there yet?',
            ],
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId:
                    'route-contextual-presence-patrol-sm1-check-there-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 20)),
                intelligenceId:
                    'INT-ROUTE-CONTEXTUAL-PRESENCE-PATROL-SM1-CHECK-THERE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId:
                    'evt-route-contextual-presence-patrol-sm1-check-there-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 69,
                canonicalHash:
                    'hash-route-contextual-presence-patrol-sm1-check-there-1',
              ),
              PatrolCompleted(
                eventId:
                    'route-contextual-presence-patrol-sm1-check-there-patrol-1',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 11)),
                routeId: 'perimeter-route',
                guardId: 'Guard011',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                durationSeconds: 420,
              ),
            ],
            expectedArea: 'Perimeter',
            updateId: 90229,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so still no one on that side since then?',
            ],
            events: missingResponseHistory(
              prefix: 'route-contextual-presence-missing-back-entrance',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91059,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so still no one over ther then?',
            ],
            events: missingResponseHistory(
              prefix: 'route-contextual-presence-missing-over-ther',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 90268,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so still no one over there then?',
            ],
            events: missingResponseHistory(
              prefix: 'route-contextual-presence-missing-over-there',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary: 'Movement at the back entrance triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91062,
            expectsArrival: false,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'so still someone there after that then?',
            ],
            events: responseArrivalHistory(
              prefix: 'route-contextual-presence-arrival-perimeter',
              zone: 'Perimeter',
              alertHeadline: 'Perimeter movement alert',
              alertSummary:
                  'Movement along the outer perimeter triggered review.',
              arrivalSummary: 'A field response unit arrived on site.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91063,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'so someone did get there then?',
            ],
            events: responseArrivalHistory(
              prefix: 'route-contextual-presence-arrival-did-get-there',
              zone: 'Perimeter',
              alertHeadline: 'Perimeter movement alert',
              alertSummary:
                  'Movement along the outer perimeter triggered review.',
              arrivalSummary: 'A field response unit arrived on site.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91065,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did they get there yet?',
            ],
            events: responseArrivalHistory(
              prefix:
                  'route-contextual-presence-arrival-did-they-get-there-yet',
              zone: 'Perimeter',
              alertHeadline: 'Perimeter movement alert',
              alertSummary:
                  'Movement along the outer perimeter triggered review.',
              arrivalSummary: 'A field response unit arrived on site.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91077,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did any1 get there yet?',
            ],
            events: responseArrivalHistory(
              prefix:
                  'route-contextual-presence-arrival-did-any1-get-there-yet',
              zone: 'Perimeter',
              alertHeadline: 'Perimeter movement alert',
              alertSummary:
                  'Movement along the outer perimeter triggered review.',
              arrivalSummary: 'A field response unit arrived on site.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 90236,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the front gate quiet earlier tonight?',
              'did any1 get to the gate yet?',
            ],
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId: 'route-contextual-presence-arrival-any1-gate-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 18)),
                intelligenceId:
                    'INT-ROUTE-CONTEXTUAL-PRESENCE-ARRIVAL-ANY1-GATE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-contextual-presence-arrival-any1-gate-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Front Gate',
                headline: 'Front gate movement alert',
                summary: 'Movement at the front gate triggered review.',
                riskScore: 72,
                canonicalHash:
                    'hash-route-contextual-presence-arrival-any1-gate-1',
              ),
              IntelligenceReceived(
                eventId: 'route-contextual-presence-arrival-any1-gate-intel-2',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 9)),
                intelligenceId:
                    'INT-ROUTE-CONTEXTUAL-PRESENCE-ARRIVAL-ANY1-GATE-2',
                provider: 'field-ops',
                sourceType: 'ops',
                externalId: 'evt-route-contextual-presence-arrival-any1-gate-2',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Front Gate',
                headline: 'Response arrival',
                summary: 'A field response unit arrived on site.',
                riskScore: 28,
                canonicalHash:
                    'hash-route-contextual-presence-arrival-any1-gate-2',
              ),
            ],
            expectedArea: 'Front Gate',
            updateId: 90239,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the front gate quiet earlier tonight?',
              'did they get to the gate after that?',
            ],
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId:
                    'route-contextual-presence-arrival-gate-after-that-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 18)),
                intelligenceId:
                    'INT-ROUTE-CONTEXTUAL-PRESENCE-ARRIVAL-GATE-AFTER-THAT-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId:
                    'evt-route-contextual-presence-arrival-gate-after-that-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Front Gate',
                headline: 'Front gate movement alert',
                summary: 'Movement at the front gate triggered review.',
                riskScore: 72,
                canonicalHash:
                    'hash-route-contextual-presence-arrival-gate-after-that-1',
              ),
              IntelligenceReceived(
                eventId:
                    'route-contextual-presence-arrival-gate-after-that-intel-2',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 8)),
                intelligenceId:
                    'INT-ROUTE-CONTEXTUAL-PRESENCE-ARRIVAL-GATE-AFTER-THAT-2',
                provider: 'field-ops',
                sourceType: 'ops',
                externalId:
                    'evt-route-contextual-presence-arrival-gate-after-that-2',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Front Gate',
                headline: 'Response arrival',
                summary: 'A field response unit arrived on site.',
                riskScore: 28,
                canonicalHash:
                    'hash-route-contextual-presence-arrival-gate-after-that-2',
              ),
            ],
            expectedArea: 'Front Gate',
            updateId: 90244,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did any1 get there since earlier?',
            ],
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId:
                    'route-contextual-presence-arrival-any1-earlier-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 22)),
                intelligenceId:
                    'INT-ROUTE-CONTEXTUAL-PRESENCE-ARRIVAL-ANY1-EARLIER-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId:
                    'evt-route-contextual-presence-arrival-any1-earlier-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                canonicalHash:
                    'hash-route-contextual-presence-arrival-any1-earlier-1',
              ),
              IntelligenceReceived(
                eventId:
                    'route-contextual-presence-arrival-any1-earlier-intel-2',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 10)),
                intelligenceId:
                    'INT-ROUTE-CONTEXTUAL-PRESENCE-ARRIVAL-ANY1-EARLIER-2',
                provider: 'field-ops',
                sourceType: 'ops',
                externalId:
                    'evt-route-contextual-presence-arrival-any1-earlier-2',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Perimeter',
                headline: 'Response arrival',
                summary: 'A field response unit arrived on site.',
                riskScore: 28,
                canonicalHash:
                    'hash-route-contextual-presence-arrival-any1-earlier-2',
              ),
            ],
            expectedArea: 'Perimeter',
            updateId: 90242,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did they arrive yet there?',
            ],
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId:
                    'route-contextual-presence-arrival-did-they-arrive-yet-there-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 18)),
                intelligenceId: 'INT-ROUTE-DID-THEY-ARRIVE-YET-THERE-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-route-did-they-arrive-yet-there-1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 74,
                canonicalHash: 'hash-route-did-they-arrive-yet-there-1',
              ),
              IntelligenceReceived(
                eventId:
                    'route-contextual-presence-arrival-did-they-arrive-yet-there-intel-2',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 9)),
                intelligenceId: 'INT-ROUTE-DID-THEY-ARRIVE-YET-THERE-2',
                provider: 'field-ops',
                sourceType: 'ops',
                externalId: 'evt-route-did-they-arrive-yet-there-2',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                zone: 'Perimeter',
                headline: 'Response arrival',
                summary: 'A field response unit arrived on site.',
                riskScore: 28,
                canonicalHash: 'hash-route-did-they-arrive-yet-there-2',
              ),
            ],
            expectedArea: 'Perimeter',
            updateId: 91080,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'so someone is there then?',
            ],
            events: responseArrivalHistory(
              prefix: 'route-contextual-presence-arrival-is-there',
              zone: 'Perimeter',
              alertHeadline: 'Perimeter movement alert',
              alertSummary:
                  'Movement along the outer perimeter triggered review.',
              arrivalSummary: 'A field response unit arrived on site.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91066,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'so someone got there after that then?',
            ],
            events: responseArrivalHistory(
              prefix: 'route-contextual-presence-arrival-after-that',
              zone: 'Perimeter',
              alertHeadline: 'Perimeter movement alert',
              alertSummary:
                  'Movement along the outer perimeter triggered review.',
              arrivalSummary: 'A field response unit arrived on site.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91067,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so someone on that side since then?',
            ],
            events: responseArrivalHistory(
              prefix: 'route-contextual-presence-arrival-that-side',
              zone: 'Back Entrance',
              alertHeadline: 'Back entrance motion alert',
              alertSummary: 'Movement at the back entrance triggered review.',
              arrivalSummary:
                  'A field response unit arrived at the back entrance.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91064,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so someone on tht side since then?',
            ],
            events: responseArrivalHistory(
              prefix: 'route-contextual-presence-arrival-tht-side',
              zone: 'Back Entrance',
              alertHeadline: 'Back entrance motion alert',
              alertSummary: 'Movement at the back entrance triggered review.',
              arrivalSummary:
                  'A field response unit arrived at the back entrance.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91060,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'did they get there on tht side?',
            ],
            events: responseArrivalHistory(
              prefix:
                  'route-contextual-presence-arrival-tht-side-did-they-get-there',
              zone: 'Back Entrance',
              alertHeadline: 'Back entrance motion alert',
              alertSummary: 'Movement at the back entrance triggered review.',
              arrivalSummary:
                  'A field response unit arrived at the back entrance.',
              riskScore: 74,
            ),
            expectedArea: 'Back Entrance',
            updateId: 90283,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'did they get there on tht side after that?',
            ],
            events: responseArrivalHistory(
              prefix:
                  'route-contextual-presence-arrival-tht-side-did-they-get-there-after',
              zone: 'Back Entrance',
              alertHeadline: 'Back entrance motion alert',
              alertSummary: 'Movement at the back entrance triggered review.',
              arrivalSummary:
                  'A field response unit arrived at the back entrance.',
              riskScore: 74,
            ),
            expectedArea: 'Back Entrance',
            updateId: 90285,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so still someone over there then?',
            ],
            events: responseArrivalHistory(
              prefix: 'route-contextual-presence-arrival-over-there',
              zone: 'Back Entrance',
              alertHeadline: 'Back entrance motion alert',
              alertSummary: 'Movement at the back entrance triggered review.',
              arrivalSummary:
                  'A field response unit arrived at the back entrance.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 91061,
            expectsArrival: true,
          ),
          (
            prompts: const <String>[
              'was the back entrance quiet earlier tonight?',
              'so still someone ovr ther then?',
            ],
            events: responseArrivalHistory(
              prefix: 'route-contextual-presence-arrival-ovr-ther',
              zone: 'Back Entrance',
              alertHeadline: 'Back entrance motion alert',
              alertSummary: 'Movement at the back entrance triggered review.',
              arrivalSummary:
                  'A field response unit arrived at the back entrance.',
              riskScore: 69,
            ),
            expectedArea: 'Back Entrance',
            updateId: 90267,
            expectsArrival: true,
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final hasPatrol = scenario.events.any(
        (event) => event is PatrolCompleted,
      );
      final arrivalStillActive = scenario.events.any(
        (event) => event is DecisionCreated,
      );
      final isGuardCheckPrompt =
          scenario.prompts.last.contains('checked that side') ||
          scenario.prompts.last.contains('check that side');
      final transcript = await sendClientTelegramConversationThroughRoute(
        tester,
        appKey: ValueKey(
          'clients-telegram-contextual-presence-matrix-app-$index',
        ),
        prompts: scenario.prompts,
        firstUpdateId: scenario.updateId,
        initialStoreEventsOverride: scenario.events,
      );

      if (hasPatrol) {
        expect(
          transcript,
          predicate<String>(
            (value) =>
                value.contains(
                  'Yes. The latest guard check tied to ${scenario.expectedArea} was logged by ',
                ) ||
                value.contains('Yes. The latest guard check was logged on') ||
                _hasGenericAreaAmbiguity(value),
            'contains a guard-check confirmation for ${scenario.expectedArea}',
          ),
          reason: scenario.prompts.last,
        );
      } else if (scenario.expectsArrival) {
        expect(
          transcript,
          predicate<String>(
            (value) =>
                _clientAreaTerms(scenario.expectedArea).any(
                  (term) => value.contains(
                    'Yes. A response arrival tied to $term was logged at ',
                  ),
                ) ||
                value.contains('Yes. A response arrival was logged at '),
            'contains an arrival confirmation for ${scenario.expectedArea}',
          ),
          reason: scenario.prompts.last,
        );
        if (arrivalStillActive) {
          expect(
            transcript,
            contains(
              'Response remains active while that area is being verified.',
            ),
            reason: scenario.prompts.last,
          );
        } else {
          expect(
            transcript,
            contains('not sitting as an active incident now.'),
            reason: scenario.prompts.last,
          );
        }
      } else if (isGuardCheckPrompt) {
        expect(
          transcript,
          predicate<String>(
            (value) =>
                value.contains(
                  'I do not have a confirmed guard check tied to ${scenario.expectedArea} yet.',
                ) ||
                value.contains(
                  'Yes. The latest guard check tied to ${scenario.expectedArea} was logged by ',
                ) ||
                value.contains('Yes. The latest guard check was logged on') ||
                _hasGenericAreaAmbiguity(value),
            'contains a guard-check outcome for ${scenario.expectedArea}',
          ),
          reason: scenario.prompts.last,
        );
      } else {
        expect(
          transcript,
          predicate<String>(
            (value) =>
                value.contains(
                  'I do not have a confirmed response arrival tied to ${scenario.expectedArea} yet.',
                ) ||
                value.contains(
                  'I do not have a confirmed response arrival yet.',
                ),
            'contains a response-arrival gap for ${scenario.expectedArea}',
          ),
          reason: scenario.prompts.last,
        );
        expect(
          transcript,
          predicate<String>(
            (value) =>
                value.contains(
                  'The current operational picture still shows ${scenario.expectedArea} under review.',
                ) ||
                value.contains(
                  'The current operational picture still shows that issue under review.',
                ),
            'contains an under-review follow-up for ${scenario.expectedArea}',
          ),
          reason: scenario.prompts.last,
        );
      }
      expect(
        transcript,
        contains(
          'I do not have live visual confirmation on ${scenario.expectedArea}',
        ),
        reason: scenario.prompts.last,
      );
      expect(
        transcript,
        isNot(contains('Unsupported command')),
        reason: scenario.prompts.last,
      );
    }
  });

  testWidgets(
    'onyx app keeps the softer contextual presence-history ambiguity matrix stable',
    (tester) async {
      final cases = <({String prompt, int updateId})>[
        (prompt: 'so someone on the other side since then?', updateId: 91062),
        (prompt: 'so still someone over there then?', updateId: 91063),
      ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey(
            'clients-telegram-contextual-presence-ambiguity-matrix-app-$index',
          ),
          prompts: <String>[
            'was the front gate quiet earlier tonight?',
            'was the back entrance quiet earlier tonight?',
            scenario.prompt,
          ],
          firstUpdateId: scenario.updateId,
          initialStoreEventsOverride: const <DispatchEvent>[],
        );

        expect(
          transcript,
          _matchesLegacyAmbiguityOrEnumeratedAreaFallback(
            legacyPattern: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
            legacyFollowUps: const <String>[
              'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
            ],
            areas: const <String>['Front Gate', 'Back Entrance'],
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('Unsupported command')),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets('onyx app keeps the softer completed-action continuity matrix stable', (
    tester,
  ) async {
    final now = _clientsMatrixNowUtc();

    List<DispatchEvent> patrolHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
      required String routeId,
      required String guardId,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 20)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        PatrolCompleted(
          eventId: '$prefix-patrol-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 11)),
          routeId: routeId,
          guardId: guardId,
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          durationSeconds: 420,
        ),
      ];
    }

    List<DispatchEvent> patrolMissingHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 18)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
      ];
    }

    List<DispatchEvent> arrivalHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
      required String arrivalSummary,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 18)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 16)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
        IntelligenceReceived(
          eventId: '$prefix-intel-2',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 9)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-2',
          provider: 'field-ops',
          sourceType: 'ops',
          externalId: 'evt-$prefix-2',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: 'Response arrival',
          summary: arrivalSummary,
          riskScore: 28,
          canonicalHash: 'hash-$prefix-2',
        ),
      ];
    }

    List<DispatchEvent> arrivalMissingHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 18)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 16)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
      ];
    }

    final cases =
        <
          ({
            List<String> prompts,
            List<DispatchEvent> events,
            String expectedArea,
            int updateId,
            String expectedLead,
            String? expectedFollowUp,
          })
        >[
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did sm1 check there yet?',
            ],
            events: patrolHistory(
              prefix: 'route-completed-action-patrol-typo',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 69,
              routeId: 'perimeter-route',
              guardId: 'Guard011',
            ),
            expectedArea: 'Perimeter',
            updateId: 91064,
            expectedLead:
                'Yes. The latest guard check tied to Perimeter was logged by Guard011 at ',
            expectedFollowUp: null,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did they get there yet?',
            ],
            events: arrivalHistory(
              prefix: 'route-completed-action-arrival-generic',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
              arrivalSummary: 'A field response unit arrived on site.',
            ),
            expectedArea: 'Perimeter',
            updateId: 91065,
            expectedLead:
                'Yes. A response arrival tied to Perimeter was logged at ',
            expectedFollowUp:
                'Response remains active while that area is being verified.',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has someone looked there yet?',
            ],
            events: patrolHistory(
              prefix: 'route-completed-action-patrol-looked',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 69,
              routeId: 'perimeter-route',
              guardId: 'Guard011',
            ),
            expectedArea: 'Perimeter',
            updateId: 91066,
            expectedLead:
                'Yes. The latest guard check tied to Perimeter was logged by Guard011 at ',
            expectedFollowUp: null,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did someone check that side yet?',
            ],
            events: patrolMissingHistory(
              prefix: 'route-completed-action-patrol-missing',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 69,
            ),
            expectedArea: 'Perimeter',
            updateId: 91067,
            expectedLead:
                'I do not have a confirmed guard check tied to Perimeter yet.',
            expectedFollowUp: null,
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'did anyone get to that side yet?',
            ],
            events: arrivalMissingHistory(
              prefix: 'route-completed-action-arrival-missing',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
            ),
            expectedArea: 'Perimeter',
            updateId: 91068,
            expectedLead:
                'I do not have a confirmed response arrival tied to Perimeter yet.',
            expectedFollowUp:
                'The current operational picture still shows recent intrusion signals around Perimeter.',
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final transcript = await sendClientTelegramConversationThroughRoute(
        tester,
        appKey: ValueKey('clients-telegram-completed-action-matrix-app-$index'),
        prompts: scenario.prompts,
        firstUpdateId: scenario.updateId,
        initialStoreEventsOverride: scenario.events,
      );

      expect(
        transcript,
        predicate<String>(
          (value) =>
              _matchesAreaAwareLead(
                value,
                expectedLead: scenario.expectedLead,
                area: scenario.expectedArea,
              ) ||
              _hasGenericAreaAmbiguity(value),
          'contains the expected completed-action lead or generic area ambiguity',
        ),
        reason: scenario.prompts.last,
      );
      if (scenario.expectedFollowUp case final expectedFollowUp?) {
        expect(
          transcript,
          predicate<String>(
            (value) =>
                value.contains(expectedFollowUp) ||
                (expectedFollowUp.contains('recent intrusion signals around') &&
                    value.contains(
                      'The current operational picture still shows that issue under review.',
                    )) ||
                _hasGenericAreaAmbiguity(value),
            'contains the expected follow-up or generic area ambiguity',
          ),
          reason: scenario.prompts.last,
        );
      }
      expect(
        transcript,
        contains(
          'I do not have live visual confirmation on ${scenario.expectedArea}',
        ),
        reason: scenario.prompts.last,
      );
      expect(
        transcript,
        isNot(contains('Unsupported command')),
        reason: scenario.prompts.last,
      );
    }
  });

  testWidgets(
    'onyx app keeps the softer completed-action continuity ambiguity matrix stable',
    (tester) async {
      final now = _clientsMatrixNowUtc();
      final ambiguityEvents = <DispatchEvent>[
        IntelligenceReceived(
          eventId: 'route-completed-action-ambiguity-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 20)),
          intelligenceId: 'INT-ROUTE-COMPLETED-ACTION-AMBIGUITY-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-route-completed-action-ambiguity-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: 'Front Gate',
          headline: 'Front gate movement alert',
          summary: 'Movement at the front gate triggered review.',
          riskScore: 67,
          canonicalHash: 'hash-route-completed-action-ambiguity-1',
        ),
        IntelligenceReceived(
          eventId: 'route-completed-action-ambiguity-intel-2',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 16)),
          intelligenceId: 'INT-ROUTE-COMPLETED-ACTION-AMBIGUITY-2',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-route-completed-action-ambiguity-2',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: 'Back Entrance',
          headline: 'Back entrance motion alert',
          summary: 'Movement at the back entrance triggered review.',
          riskScore: 69,
          canonicalHash: 'hash-route-completed-action-ambiguity-2',
        ),
      ];

      final cases = <({String prompt, int updateId})>[
        (prompt: 'did they get to the other side yet?', updateId: 91069),
        (prompt: 'did they get to the othr side yet?', updateId: 91070),
        (prompt: 'did they get there on the other side?', updateId: 91071),
      ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey(
            'clients-telegram-completed-action-ambiguity-matrix-app-$index',
          ),
          prompts: <String>[
            'pls check front gate',
            'pls check back entrance',
            scenario.prompt,
          ],
          firstUpdateId: scenario.updateId,
          initialStoreEventsOverride: ambiguityEvents,
        );

        expect(
          transcript,
          _matchesLegacyAmbiguityOrEnumeratedAreaFallback(
            legacyPattern: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
            legacyFollowUps: const <String>[
              'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
            ],
            areas: const <String>['Front Gate', 'Back Entrance'],
          ),
          reason: scenario.prompt,
        );
        expect(
          transcript,
          isNot(contains('Unsupported command')),
          reason: scenario.prompt,
        );
      }
    },
  );

  testWidgets('onyx app keeps the anchored calm follow-up matrix stable', (
    tester,
  ) async {
    final now = _clientsMatrixNowUtc();

    List<DispatchEvent> guardSettledHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
      required String routeId,
      required String guardId,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 21)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 19)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
        PatrolCompleted(
          eventId: '$prefix-patrol-1',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 11)),
          routeId: routeId,
          guardId: guardId,
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          durationSeconds: 480,
        ),
        IncidentClosed(
          eventId: '$prefix-closed-1',
          sequence: 4,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 5)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          resolutionType: 'all_clear',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
      ];
    }

    List<DispatchEvent> guardActiveHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
      required String routeId,
      required String guardId,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 19)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 17)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
        PatrolCompleted(
          eventId: '$prefix-patrol-1',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 8)),
          routeId: routeId,
          guardId: guardId,
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          durationSeconds: 14 * 60,
        ),
      ];
    }

    List<DispatchEvent> dispatchSettledHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 24)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 22)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
        IncidentClosed(
          eventId: '$prefix-closed-1',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 6)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          resolutionType: 'all_clear',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
      ];
    }

    List<DispatchEvent> cameraReviewSettledHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
      required String reviewSummary,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 21)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 19)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
        IntelligenceReceived(
          eventId: '$prefix-intel-2',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 12)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-2',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-2',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: 'Camera check complete',
          summary: reviewSummary,
          riskScore: 18,
          canonicalHash: 'hash-$prefix-2',
        ),
        IncidentClosed(
          eventId: '$prefix-closed-1',
          sequence: 4,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 5)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          resolutionType: 'all_clear',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
      ];
    }

    List<DispatchEvent> cameraReviewMissingHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 21)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 19)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
      ];
    }

    List<DispatchEvent> arrivalSettledHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
      required String arrivalSummary,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 18)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 16)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
        IntelligenceReceived(
          eventId: '$prefix-intel-2',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 9)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-2',
          provider: 'field-ops',
          sourceType: 'ops',
          externalId: 'evt-$prefix-2',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: 'Response arrival',
          summary: arrivalSummary,
          riskScore: 28,
          canonicalHash: 'hash-$prefix-2',
        ),
        IncidentClosed(
          eventId: '$prefix-closed-1',
          sequence: 4,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 4)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          resolutionType: 'all_clear',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
      ];
    }

    List<DispatchEvent> arrivalActiveHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
      required String arrivalSummary,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 18)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 16)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
        IntelligenceReceived(
          eventId: '$prefix-intel-2',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 8)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-2',
          provider: 'field-ops',
          sourceType: 'ops',
          externalId: 'evt-$prefix-2',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: 'Response arrival',
          summary: arrivalSummary,
          riskScore: 28,
          canonicalHash: 'hash-$prefix-2',
        ),
      ];
    }

    final cases =
        <
          ({
            List<String> prompts,
            List<DispatchEvent> events,
            int updateId,
            String expectedLead,
            String? expectedAnchorLine,
            String? expectedStatusLine,
            String? expectedArea,
          })
        >[
          (
            prompts: const <String>[
              'was tht alrm serious',
              'has it been quiet since the guard checked?',
            ],
            events: guardSettledHistory(
              prefix: 'route-anchored-calm-guard',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary:
                  'Repeated movement triggered review at the back entrance.',
              riskScore: 68,
              routeId: 'BACK-ENTRANCE',
              guardId: 'Guard014',
            ),
            updateId: 91072,
            expectedLead:
                'Yes. Back Entrance has been calm since the guard check at ',
            expectedAnchorLine:
                'The latest guard check tied to Back Entrance was logged by Guard014 at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Back Entrance',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has that side been calm since the patrol passed?',
            ],
            events: guardActiveHistory(
              prefix: 'route-anchored-calm-patrol-active',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
              routeId: 'NORTH-PERIMETER',
              guardId: 'Guard009',
            ),
            updateId: 91073,
            expectedLead:
                'No. The current operational picture still points to Perimeter.',
            expectedAnchorLine:
                'The latest guard check tied to Perimeter was logged by Guard009 at ',
            expectedStatusLine: 'Response is still active.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has that side been calm since dispatch was opened there?',
            ],
            events: dispatchSettledHistory(
              prefix: 'route-anchored-calm-dispatch',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 69,
            ),
            updateId: 91074,
            expectedLead:
                'Yes. Perimeter has remained calm since dispatch was opened at ',
            expectedAnchorLine: 'The dispatch tied to Perimeter was opened at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'has the entrance side been calm since dispatch was opened?',
            ],
            events: dispatchSettledHistory(
              prefix: 'route-anchored-calm-dispatch-entrance',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary:
                  'Repeated movement triggered review at the back entrance.',
              riskScore: 69,
            ),
            updateId: 91088,
            expectedLead:
                'Yes. Back Entrance has remained calm since dispatch was opened at ',
            expectedAnchorLine:
                'The dispatch tied to Back Entrance was opened at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Back Entrance',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'has the entrance side been calm since the cameras were checked there?',
            ],
            events: cameraReviewSettledHistory(
              prefix: 'route-anchored-calm-camera-check',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary:
                  'Repeated movement triggered review at the back entrance.',
              riskScore: 69,
              reviewSummary:
                  'Cameras were checked at the back entrance and no further movement was confirmed.',
            ),
            updateId: 91075,
            expectedLead:
                'Yes. Back Entrance has appeared calm since the last confirmed camera review at ',
            expectedAnchorLine:
                'A confirmed camera review marker tied to Back Entrance was logged at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Back Entrance',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'has that entrance been quiet since they checked it?',
            ],
            events: guardSettledHistory(
              prefix: 'route-anchored-calm-they-checked',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary:
                  'Repeated movement triggered review at the back entrance.',
              riskScore: 69,
              routeId: 'back-entrance-route',
              guardId: 'Guard009',
            ),
            updateId: 91076,
            expectedLead:
                'Yes. Back Entrance has been calm since the guard check at ',
            expectedAnchorLine:
                'The latest guard check tied to Back Entrance was logged by Guard009 at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Back Entrance',
          ),
          (
            prompts: const <String>[
              'was the front gate quiet earlier tonight?',
              'has the gate been quiet since sm1 checked the gate?',
            ],
            events: guardSettledHistory(
              prefix: 'route-anchored-calm-sm1-checked-gate',
              zone: 'Front Gate',
              headline: 'Front gate motion alert',
              summary: 'Repeated movement triggered review at the front gate.',
              riskScore: 69,
              routeId: 'front-gate-route',
              guardId: 'Guard003',
            ),
            updateId: 91089,
            expectedLead:
                'Yes. Front Gate has been calm since the guard check at ',
            expectedAnchorLine:
                'The latest guard check tied to Front Gate was logged by Guard003 at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Front Gate',
          ),
          (
            prompts: const <String>[
              'was the front gate quiet earlier tonight?',
              'has the gate been quiet since they checked the gate?',
            ],
            events: guardSettledHistory(
              prefix: 'route-anchored-calm-they-checked-gate',
              zone: 'Front Gate',
              headline: 'Front gate motion alert',
              summary: 'Repeated movement triggered review at the front gate.',
              riskScore: 69,
              routeId: 'front-gate-route',
              guardId: 'Guard003',
            ),
            updateId: 91090,
            expectedLead:
                'Yes. Front Gate has been calm since the guard check at ',
            expectedAnchorLine:
                'The latest guard check tied to Front Gate was logged by Guard003 at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Front Gate',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'has that side been calm since the response arrived?',
            ],
            events: arrivalActiveHistory(
              prefix: 'route-anchored-calm-arrival-active',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
              arrivalSummary: 'A field response unit arrived on site.',
            ),
            updateId: 91080,
            expectedLead:
                'No. The current operational picture still points to Perimeter.',
            expectedAnchorLine:
                'A response arrival tied to Perimeter was logged at ',
            expectedStatusLine: 'Response is still active.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has it stayed calm since sm1 got there?',
            ],
            events: arrivalSettledHistory(
              prefix: 'route-anchored-calm-arrival',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
              arrivalSummary: 'A field response unit arrived on site.',
            ),
            updateId: 91077,
            expectedLead:
                'Yes. Perimeter has appeared calm since the response arrived at ',
            expectedAnchorLine:
                'A response arrival tied to Perimeter was logged at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has it stayed calm since the team arrived there?',
            ],
            events: arrivalSettledHistory(
              prefix: 'route-anchored-calm-team-arrived',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
              arrivalSummary: 'A field response unit arrived on site.',
            ),
            updateId: 91081,
            expectedLead:
                'Yes. Perimeter has appeared calm since the response arrived at ',
            expectedAnchorLine:
                'A response arrival tied to Perimeter was logged at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has it stayed calm since the guys got there?',
            ],
            events: arrivalSettledHistory(
              prefix: 'route-anchored-calm-guys-arrived',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
              arrivalSummary: 'A field response unit arrived on site.',
            ),
            updateId: 91082,
            expectedLead:
                'Yes. Perimeter has appeared calm since the response arrived at ',
            expectedAnchorLine:
                'A response arrival tied to Perimeter was logged at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has it stayed calm since they got there?',
            ],
            events: arrivalSettledHistory(
              prefix: 'route-anchored-calm-they-arrived',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
              arrivalSummary: 'A field response unit arrived on site.',
            ),
            updateId: 91083,
            expectedLead:
                'Yes. Perimeter has appeared calm since the response arrived at ',
            expectedAnchorLine:
                'A response arrival tied to Perimeter was logged at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has it stayed calm since thy got there?',
            ],
            events: arrivalSettledHistory(
              prefix: 'route-anchored-calm-thy-arrived',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
              arrivalSummary: 'A field response unit arrived on site.',
            ),
            updateId: 91084,
            expectedLead:
                'Yes. Perimeter has appeared calm since the response arrived at ',
            expectedAnchorLine:
                'A response arrival tied to Perimeter was logged at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has it been calm since sm1 got there?',
            ],
            events: arrivalSettledHistory(
              prefix: 'route-anchored-calm-sm1-arrived',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
              arrivalSummary: 'A field response unit arrived on site.',
            ),
            updateId: 91085,
            expectedLead:
                'Yes. Perimeter has appeared calm since the response arrived at ',
            expectedAnchorLine:
                'A response arrival tied to Perimeter was logged at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has that side been quiet since they looked at it?',
            ],
            events: guardSettledHistory(
              prefix: 'route-anchored-calm-they-looked',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 69,
              routeId: 'perimeter-route',
              guardId: 'Guard011',
            ),
            updateId: 91078,
            expectedLead:
                'Yes. Perimeter has been calm since the guard check at ',
            expectedAnchorLine:
                'The latest guard check tied to Perimeter was logged by Guard011 at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has that side been quiet since someone checked that side?',
            ],
            events: guardSettledHistory(
              prefix: 'route-anchored-calm-someone-checked',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 69,
              routeId: 'perimeter-route',
              guardId: 'Guard011',
            ),
            updateId: 91086,
            expectedLead:
                'Yes. Perimeter has been calm since the guard check at ',
            expectedAnchorLine:
                'The latest guard check tied to Perimeter was logged by Guard011 at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was the perimeter side quiet earlier tonight?',
              'has that side been quiet since some1 looked there?',
            ],
            events: guardSettledHistory(
              prefix: 'route-anchored-calm-some1-looked',
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 69,
              routeId: 'perimeter-route',
              guardId: 'Guard011',
            ),
            updateId: 91087,
            expectedLead:
                'Yes. Perimeter has been calm since the guard check at ',
            expectedAnchorLine:
                'The latest guard check tied to Perimeter was logged by Guard011 at ',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'has the entrance side been calm since the cameras were reviewed?',
            ],
            events: cameraReviewMissingHistory(
              prefix: 'route-anchored-calm-camera-missing',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary:
                  'Repeated movement triggered review at the back entrance.',
              riskScore: 69,
            ),
            updateId: 91079,
            expectedLead:
                'I do not have a confirmed camera review marker tied to Back Entrance that I can anchor that calmness check to right now.',
            expectedAnchorLine: null,
            expectedStatusLine: null,
            expectedArea: 'Back Entrance',
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final transcript = await sendClientTelegramConversationThroughRoute(
        tester,
        appKey: ValueKey('clients-telegram-anchored-calm-matrix-app-$index'),
        prompts: scenario.prompts,
        firstUpdateId: scenario.updateId,
        initialStoreEventsOverride: scenario.events,
      );

      expect(
        transcript,
        predicate<String>(
          (value) =>
              value.contains(scenario.expectedLead) ||
              value.contains('Yes. The area in question appears calm since') ||
              value.contains(
                'Yes. The earlier issue has remained calm since dispatch was opened at ',
              ) ||
              _clientAreaTerms(scenario.expectedArea ?? '').any(
                (term) => value.contains(
                  'I do not have a confirmed camera review marker tied to $term that I can anchor that calmness check to right now.',
                ),
              ) ||
              _clientAreaTerms(scenario.expectedArea ?? '').any(
                (term) => value.contains(
                  'Yes. $term has appeared calm since the last confirmed camera review at ',
                ),
              ) ||
              _clientAreaTerms(scenario.expectedArea ?? '').any(
                (term) => value.contains(
                  'Yes. $term has been calm since the guard check at ',
                ),
              ) ||
              _clientAreaTerms(scenario.expectedArea ?? '').any(
                (term) => value.contains(
                  'Yes. $term has remained calm since dispatch was opened at ',
                ),
              ) ||
              value.contains(
                'No. The current operational picture does not look calm yet.',
              ),
          'contains the anchored calm lead',
        ),
        reason: scenario.prompts.last,
      );
      if (scenario.expectedAnchorLine case final expectedAnchorLine?) {
        expect(
          transcript,
          predicate<String>(
            (value) =>
                value.contains(expectedAnchorLine) ||
                value.contains('The latest guard check was logged on') ||
                value.contains('The relevant dispatch was opened at ') ||
                value.contains('A response arrival was logged at ') ||
                _clientAreaTerms(scenario.expectedArea ?? '').any(
                  (term) => value.contains(
                    'A confirmed camera review marker tied to $term was logged at ',
                  ),
                ) ||
                _clientAreaTerms(scenario.expectedArea ?? '').any(
                  (term) => value.contains(
                    'The latest guard check tied to $term was logged by',
                  ),
                ) ||
                _clientAreaTerms(scenario.expectedArea ?? '').any(
                  (term) => value.contains(
                    'The dispatch tied to $term was opened at ',
                  ),
                ),
            'contains the anchored calm detail',
          ),
          reason: scenario.prompts.last,
        );
      }
      if (scenario.expectedStatusLine case final expectedStatusLine?) {
        expect(
          transcript,
          contains(expectedStatusLine),
          reason: scenario.prompts.last,
        );
      }
      if (scenario.expectedArea != null) {
        expect(
          transcript,
          contains('I do not have live visual confirmation'),
          reason: scenario.prompts.last,
        );
      }
      expect(
        transcript,
        isNot(contains('Unsupported command')),
        reason: scenario.prompts.last,
      );
    }
  });

  testWidgets('onyx app keeps the incident continuity calmness matrix stable', (
    tester,
  ) async {
    final now = _clientsMatrixNowUtc();
    final localNow = _clientsScenarioLocalNow();
    final localEarlierTonight = localNow.hour >= 18
        ? DateTime(localNow.year, localNow.month, localNow.day, 21, 14)
        : DateTime(
            localNow.year,
            localNow.month,
            localNow.day,
            21,
            14,
          ).subtract(const Duration(days: 1));

    List<DispatchEvent> activeHistory({
      required String prefix,
      required DateTime occurredAt,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: occurredAt,
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: occurredAt.add(const Duration(minutes: 2)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
      ];
    }

    List<DispatchEvent> settledHistory({
      required String prefix,
      required String zone,
      required String headline,
      required String summary,
      required int riskScore,
    }) {
      return <DispatchEvent>[
        IntelligenceReceived(
          eventId: '$prefix-intel-1',
          sequence: 1,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 18)),
          intelligenceId: 'INT-${prefix.toUpperCase()}-1',
          provider: 'hikvision-dvr',
          sourceType: 'dvr',
          externalId: 'evt-$prefix-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
          zone: zone,
          headline: headline,
          summary: summary,
          riskScore: riskScore,
          canonicalHash: 'hash-$prefix-1',
        ),
        DecisionCreated(
          eventId: '$prefix-decision-1',
          sequence: 2,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 16)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
        IncidentClosed(
          eventId: '$prefix-closed-1',
          sequence: 3,
          version: 1,
          occurredAt: now.subtract(const Duration(minutes: 4)),
          dispatchId: 'DSP-${prefix.toUpperCase()}-1',
          resolutionType: 'all_clear',
          clientId: 'CLIENT-DEMO',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-DEMO',
        ),
      ];
    }

    final cases =
        <
          ({
            List<String> prompts,
            List<DispatchEvent> events,
            int updateId,
            String expectedLead,
            String expectedStatusLine,
            String expectedArea,
          })
        >[
          (
            prompts: const <String>[
              'was tht alrm serious',
              'was the entrance side quiet since then?',
            ],
            events: settledHistory(
              prefix: 'route-continuity-quiet-since-then',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary:
                  'Repeated movement triggered review at the back entrance.',
              riskScore: 70,
            ),
            updateId: 91080,
            expectedLead:
                'Yes. Back Entrance has been calm since the earlier signal.',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Back Entrance',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'is it still the same issue?',
            ],
            events: activeHistory(
              prefix: 'route-continuity-same-issue',
              occurredAt: now.subtract(const Duration(minutes: 10)),
              zone: 'Front Gate',
              headline: 'Front gate motion alert',
              summary: 'Repeated movement triggered review at the front gate.',
              riskScore: 79,
            ),
            updateId: 91081,
            expectedLead: 'The current operational picture still',
            expectedStatusLine: 'Response is still active.',
            expectedArea: 'Front Gate',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'did that settle down?',
            ],
            events: settledHistory(
              prefix: 'route-continuity-settled',
              zone: 'Front Gate',
              headline: 'Front gate motion alert',
              summary: 'Repeated movement triggered review at the front gate.',
              riskScore: 74,
            ),
            updateId: 91082,
            expectedLead: 'The earlier Front Gate signal has settled.',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Front Gate',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'was that from earlier tonight?',
            ],
            events: activeHistory(
              prefix: 'route-continuity-earlier-tonight',
              occurredAt: localEarlierTonight.toUtc(),
              zone: 'Front Gate',
              headline: 'Front gate motion alert',
              summary: 'Repeated movement triggered review at the front gate.',
              riskScore: 79,
            ),
            updateId: 91083,
            expectedLead: 'recorded at 21:14',
            expectedStatusLine: 'Response is still active.',
            expectedArea: 'Front Gate',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'was the perimeter side quiet earlier tonight?',
            ],
            events: activeHistory(
              prefix: 'route-continuity-perimeter-earlier-tonight',
              occurredAt: localEarlierTonight.toUtc(),
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 72,
            ),
            updateId: 91084,
            expectedLead: 'recorded at 21:14',
            expectedStatusLine: 'Response is still active.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'has the perimeter side been calm since earlier?',
            ],
            events: activeHistory(
              prefix: 'route-continuity-perimeter-since-earlier',
              occurredAt: now.subtract(const Duration(minutes: 18)),
              zone: 'Perimeter',
              headline: 'Perimeter movement alert',
              summary: 'Movement along the outer perimeter triggered review.',
              riskScore: 74,
            ),
            updateId: 91085,
            expectedLead:
                'No. The current operational picture still points to Perimeter.',
            expectedStatusLine: 'Response is still active.',
            expectedArea: 'Perimeter',
          ),
          (
            prompts: const <String>[
              'was tht alrm serious',
              'did the same entrance settle down?',
            ],
            events: settledHistory(
              prefix: 'route-continuity-same-entrance-settled',
              zone: 'Back Entrance',
              headline: 'Back entrance motion alert',
              summary:
                  'Repeated movement triggered review at the back entrance.',
              riskScore: 71,
            ),
            updateId: 91086,
            expectedLead: 'The earlier Back Entrance signal has settled.',
            expectedStatusLine:
                'It was reviewed properly and is not sitting as an active incident now.',
            expectedArea: 'Back Entrance',
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final transcript = await sendClientTelegramConversationThroughRoute(
        tester,
        appKey: ValueKey(
          'clients-telegram-incident-continuity-calmness-matrix-app-$index',
        ),
        prompts: scenario.prompts,
        firstUpdateId: scenario.updateId,
        initialStoreEventsOverride: scenario.events,
      );

      expect(
        transcript,
        predicate<String>(
          (value) =>
              _matchesAreaAwareLead(
                value,
                expectedLead: scenario.expectedLead,
                area: scenario.expectedArea,
              ) ||
              _hasSettledSignalLead(value, scenario.expectedArea),
          'contains the expected continuity lead for ${scenario.expectedArea}',
        ),
        reason: scenario.prompts.last,
      );
      expect(
        transcript,
        contains(scenario.expectedStatusLine),
        reason: scenario.prompts.last,
      );
      expect(
        transcript,
        predicate<String>(
          (value) => _hasVisualGap(value, scenario.expectedArea),
          'contains a visual confirmation gap for ${scenario.expectedArea}',
        ),
        reason: scenario.prompts.last,
      );
      expect(
        transcript,
        isNot(contains('Unsupported command')),
        reason: scenario.prompts.last,
      );
    }
  });

  testWidgets(
    'onyx app keeps the directional and landmark context matrix stable',
    (tester) async {
      final now = _clientsMatrixNowUtc();
      final localNow = _clientsScenarioLocalNow();
      final localEarlierTonight = localNow.hour >= 18
          ? DateTime(localNow.year, localNow.month, localNow.day, 21, 14)
          : DateTime(
              localNow.year,
              localNow.month,
              localNow.day,
              21,
              14,
            ).subtract(const Duration(days: 1));

      List<DispatchEvent> verificationHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
        Duration offset = const Duration(minutes: 10),
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(offset),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
        ];
      }

      List<DispatchEvent> activeIncidentHistory({
        required String prefix,
        required DateTime occurredAt,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: occurredAt,
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: occurredAt.add(const Duration(minutes: 2)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
          ),
        ];
      }

      List<DispatchEvent> settledIncidentHistory({
        required String prefix,
        required String zone,
        required String headline,
        required String summary,
        required int riskScore,
      }) {
        return <DispatchEvent>[
          IntelligenceReceived(
            eventId: '$prefix-intel-1',
            sequence: 1,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 18)),
            intelligenceId: 'INT-${prefix.toUpperCase()}-1',
            provider: 'hikvision-dvr',
            sourceType: 'dvr',
            externalId: 'evt-$prefix-1',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            zone: zone,
            headline: headline,
            summary: summary,
            riskScore: riskScore,
            canonicalHash: 'hash-$prefix-1',
          ),
          DecisionCreated(
            eventId: '$prefix-decision-1',
            sequence: 2,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 16)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
          ),
          IncidentClosed(
            eventId: '$prefix-closed-1',
            sequence: 3,
            version: 1,
            occurredAt: now.subtract(const Duration(minutes: 4)),
            dispatchId: 'DSP-${prefix.toUpperCase()}-1',
            resolutionType: 'all_clear',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
          ),
        ];
      }

      final cases =
          <
            ({
              List<String> prompts,
              List<DispatchEvent> events,
              int updateId,
              String expectedLead,
              String? expectedDetail,
              String expectedArea,
            })
          >[
            (
              prompts: const <String>[
                'was tht alrm serious',
                'was that the back one from earlier tonight?',
              ],
              events: activeIncidentHistory(
                prefix: 'route-directional-back-one-earlier-tonight',
                occurredAt: localEarlierTonight.toUtc(),
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 76,
              ),
              updateId: 91087,
              expectedLead: 'recorded at 21:14',
              expectedDetail: 'Response is still active.',
              expectedArea: 'Back Entrance',
            ),
            (
              prompts: const <String>[
                'pls check front gate',
                'pls check the driveway',
                'check the one by the driveway',
              ],
              events: verificationHistory(
                prefix: 'route-directional-driveway-landmark',
                zone: 'Driveway',
                headline: 'Driveway motion alert',
                summary: 'Vehicle movement triggered a review on the driveway.',
                riskScore: 58,
              ),
              updateId: 91088,
              expectedLead: 'The latest verified activity near Driveway was',
              expectedDetail: null,
              expectedArea: 'Driveway',
            ),
            (
              prompts: const <String>['check the driveway side'],
              events: verificationHistory(
                prefix: 'route-directional-driveway-side',
                zone: 'Driveway',
                headline: 'Driveway motion alert',
                summary: 'Vehicle movement triggered a review on the driveway.',
                riskScore: 57,
                offset: const Duration(minutes: 12),
              ),
              updateId: 91089,
              expectedLead: 'The latest verified activity near Driveway was',
              expectedDetail: null,
              expectedArea: 'Driveway',
            ),
            (
              prompts: const <String>[
                'was tht alrm serious',
                'was that the other entrance from before?',
              ],
              events: activeIncidentHistory(
                prefix: 'route-directional-other-entrance',
                occurredAt: now.subtract(const Duration(minutes: 18)),
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 74,
              ),
              updateId: 91090,
              expectedLead:
                  'The latest confirmed alert points to Back Entrance again.',
              expectedDetail: 'Response is still active.',
              expectedArea: 'Back Entrance',
            ),
            (
              prompts: const <String>[
                'pls check front gate',
                'pls check back entrance',
                'check the one by the entrance',
              ],
              events: verificationHistory(
                prefix: 'route-directional-entrance-proximity',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 65,
                offset: const Duration(minutes: 13),
              ),
              updateId: 91091,
              expectedLead:
                  'The latest verified activity near Back Entrance was',
              expectedDetail: null,
              expectedArea: 'Back Entrance',
            ),
            (
              prompts: const <String>[
                'was tht alrm serious',
                'did the perimeter side settle down?',
              ],
              events: settledIncidentHistory(
                prefix: 'route-directional-perimeter-side-settled',
                zone: 'Perimeter',
                headline: 'Perimeter movement alert',
                summary: 'Movement along the outer perimeter triggered review.',
                riskScore: 63,
              ),
              updateId: 91092,
              expectedLead: 'The earlier Perimeter signal has settled.',
              expectedDetail:
                  'It was reviewed properly and is not sitting as an active incident now.',
              expectedArea: 'Perimeter',
            ),
            (
              prompts: const <String>[
                'pls check front gate',
                'pls check back entrance',
                'check the one near the back',
              ],
              events: verificationHistory(
                prefix: 'route-directional-back-proximity',
                zone: 'Back Entrance',
                headline: 'Back entrance motion alert',
                summary:
                    'Repeated movement triggered review at the back entrance.',
                riskScore: 68,
                offset: const Duration(minutes: 18),
              ),
              updateId: 91093,
              expectedLead:
                  'The latest verified activity near Back Entrance was',
              expectedDetail:
                  'Repeated movement triggered review at the back entrance at',
              expectedArea: 'Back Entrance',
            ),
          ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final transcript = await sendClientTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey(
            'clients-telegram-directional-landmark-matrix-app-$index',
          ),
          prompts: scenario.prompts,
          firstUpdateId: scenario.updateId,
          initialStoreEventsOverride: scenario.events,
        );

        expect(
          transcript,
          predicate<String>(
            (value) => _matchesAreaAwareLead(
              value,
              expectedLead: scenario.expectedLead,
              area: scenario.expectedArea,
            ),
            'contains the expected directional or landmark lead',
          ),
          reason: scenario.prompts.last,
        );
        if (scenario.expectedDetail case final expectedDetail?) {
          expect(
            transcript,
            contains(expectedDetail),
            reason: scenario.prompts.last,
          );
        }
        expect(
          transcript,
          contains('I do not have live visual confirmation'),
          reason: scenario.prompts.last,
        );
        expect(
          transcript,
          isNot(contains('Unsupported command')),
          reason: scenario.prompts.last,
        );
      }
    },
  );

  testWidgets('onyx app keeps the directional and landmark ambiguity matrix stable', (
    tester,
  ) async {
    final cases =
        <
          ({
            List<String> prompts,
            int updateId,
            RegExp expectedAnchor,
            String expectedFollowUp,
          })
        >[
          (
            prompts: const <String>[
              'pls check front entrance',
              'pls check back entrance',
              'check the entrance side',
            ],
            updateId: 91094,
            expectedAnchor: RegExp(
              'I’m not fully certain whether you mean (Front Entrance or Back Entrance|Back Entrance or Front Entrance)\\.',
            ),
            expectedFollowUp:
                'If you tell me which one you want checked first, I’ll focus the next verified update there.',
          ),
          (
            prompts: const <String>[
              'pls check front gate',
              'pls check back gate',
              'did the far side settle down?',
            ],
            updateId: 91095,
            expectedAnchor: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
            ),
            expectedFollowUp:
                'If you tell me which one you mean, I’ll anchor the next verified answer there.',
          ),
          (
            prompts: const <String>[
              'pls check front gate',
              'pls check back gate',
              'did that side settle down?',
            ],
            updateId: 91096,
            expectedAnchor: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
            ),
            expectedFollowUp:
                'If you tell me which one you mean, I’ll anchor the next verified answer there.',
          ),
          (
            prompts: const <String>[
              'pls check front gate',
              'pls check back gate',
              'did the left side settle down?',
            ],
            updateId: 91101,
            expectedAnchor: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
            ),
            expectedFollowUp:
                'If you tell me which one you mean, I’ll anchor the next verified answer there.',
          ),
          (
            prompts: const <String>[
              'pls check front gate',
              'pls check back entrance',
              'did they get to the other side yet?',
            ],
            updateId: 91102,
            expectedAnchor: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
            expectedFollowUp:
                'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
          ),
          (
            prompts: const <String>[
              'pls check front gate',
              'pls check back entrance',
              'did they get to the othr side yet?',
            ],
            updateId: 91103,
            expectedAnchor: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
            expectedFollowUp:
                'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
          ),
          (
            prompts: const <String>[
              'pls check front gate',
              'pls check back entrance',
              'did they get there on the other side?',
            ],
            updateId: 91104,
            expectedAnchor: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
            expectedFollowUp:
                'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
          ),
          (
            prompts: const <String>[
              'was the front gate quiet earlier tonight?',
              'was the back entrance quiet earlier tonight?',
              'so someone on the other side since then?',
            ],
            updateId: 91105,
            expectedAnchor: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
            expectedFollowUp:
                'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
          ),
          (
            prompts: const <String>[
              'was the front gate quiet earlier tonight?',
              'was the back entrance quiet earlier tonight?',
              'so still someone over there then?',
            ],
            updateId: 91106,
            expectedAnchor: RegExp(
              'I’m not fully certain whether you mean (Front Gate or Back Entrance|Back Entrance or Front Gate)\\.',
            ),
            expectedFollowUp:
                'If you tell me which one you mean, I’ll confirm whether response has arrived there.',
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final transcript = await sendClientTelegramConversationThroughRoute(
        tester,
        appKey: ValueKey(
          'clients-telegram-directional-landmark-ambiguity-matrix-app-$index',
        ),
        prompts: scenario.prompts,
        firstUpdateId: scenario.updateId,
      );

      expect(
        transcript,
        _matchesLegacyAmbiguityOrEnumeratedAreaFallback(
          legacyPattern: scenario.expectedAnchor,
          legacyFollowUps: <String>[scenario.expectedFollowUp],
          areas: switch (index) {
            0 => const <String>['Front Entrance', 'Back Entrance'],
            1 || 2 || 3 => const <String>['Front Gate', 'Back Gate'],
            _ =>
              scenario.prompts[0].contains('front gate') &&
                      scenario.prompts[1].contains('back entrance')
                  ? const <String>['Front Gate', 'Back Entrance']
                  : const <String>['Front Gate', 'Back Gate'],
          },
        ),
        reason: scenario.prompts.last,
      );
      expect(
        transcript,
        isNot(contains('Unsupported command')),
        reason: scenario.prompts.last,
      );
    }
  });

  testWidgets('onyx app keeps the other-one ambiguity matrix stable', (
    tester,
  ) async {
    final cases = <({List<String> prompts, int updateId, String expectedFollowUp})>[
      (
        prompts: const <String>[
          'pls check front gate',
          'pls check back gate',
          'check the other one',
        ],
        updateId: 91097,
        expectedFollowUp:
            'If you tell me which one you want checked first, I’ll focus the next verified update there.',
      ),
      (
        prompts: const <String>[
          'pls check front gate',
          'pls check back gate',
          'did they check the other one?',
        ],
        updateId: 91098,
        expectedFollowUp:
            'If you tell me which one you mean, I’ll confirm whether it was checked.',
      ),
      (
        prompts: const <String>[
          'pls check front gate',
          'pls check back gate',
          'did they check the othr one?',
        ],
        updateId: 91099,
        expectedFollowUp:
            'If you tell me which one you mean, I’ll confirm whether it was checked.',
      ),
      (
        prompts: const <String>[
          'pls check front gate',
          'pls check back gate',
          'did they check tht one?',
        ],
        updateId: 91100,
        expectedFollowUp:
            'If you tell me which one you mean, I’ll confirm whether it was checked.',
      ),
    ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final transcript = await sendClientTelegramConversationThroughRoute(
        tester,
        appKey: ValueKey(
          'clients-telegram-other-one-ambiguity-matrix-app-$index',
        ),
        prompts: scenario.prompts,
        firstUpdateId: scenario.updateId,
      );

      expect(
        transcript,
        _matchesLegacyAmbiguityOrEnumeratedAreaFallback(
          legacyPattern: RegExp(
            'I’m not fully certain whether you mean (Front Gate or Back Gate|Back Gate or Front Gate)\\.',
          ),
          legacyFollowUps: <String>[scenario.expectedFollowUp],
          areas: const <String>['Front Gate', 'Back Gate'],
        ),
        reason: scenario.prompts.last,
      );
      expect(
        transcript,
        isNot(contains('Unsupported command')),
        reason: scenario.prompts.last,
      );
    }
  });

  testWidgets(
    'onyx app keeps the deterministic client incident-read matrix stable',
    (tester) async {
      final now = _clientsMatrixNowUtc();
      final localNow = _clientsScenarioLocalNow();
      final end = DateTime(localNow.year, localNow.month, localNow.day, 6);
      final start = DateTime(
        end.year,
        end.month,
        end.day,
      ).subtract(const Duration(days: 1)).add(const Duration(hours: 18));
      final latestInWindow = localNow.isBefore(end)
          ? localNow.subtract(const Duration(minutes: 1))
          : end.subtract(const Duration(minutes: 5));

      final cases =
          <
            ({
              List<String> prompts,
              List<DispatchEvent> events,
              int updateId,
              DateTime? sentAtUtc,
              String chatType,
              List<String> expected,
              List<String> forbidden,
            })
          >[
            (
              prompts: const <String>['Show unresolved incidents'],
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'decision-telegram-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 18)),
                  dispatchId: 'DSP-1',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
                DecisionCreated(
                  eventId: 'decision-telegram-2',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 7)),
                  dispatchId: 'DSP-2',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
                IncidentClosed(
                  eventId: 'closed-telegram-1',
                  sequence: 3,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 4)),
                  dispatchId: 'DSP-1',
                  resolutionType: 'all_clear',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
              ],
              updateId: 9003,
              sentAtUtc: _clientsQuickActionSentAtUtc(22, 35),
              chatType: 'private',
              expected: const <String>['No unresolved incidents in Demo.'],
              forbidden: const <String>[],
            ),
            for (final scenario in <({String prompt, int updateId})>[
              (prompt: 'Check breaches', updateId: 90311),
              (prompt: 'Show breaches', updateId: 90312),
              (prompt: 'Any breaches', updateId: 90313),
              (prompt: 'Breach status', updateId: 90314),
              (prompt: 'Do we have any breaches?', updateId: 90315),
              (prompt: 'Breaches at the site?', updateId: 90316),
            ])
              (
                prompts: <String>[scenario.prompt],
                events: <DispatchEvent>[
                  DecisionCreated(
                    eventId:
                        'decision-telegram-breach-open-${scenario.updateId}',
                    sequence: 1,
                    version: 1,
                    occurredAt: now.subtract(const Duration(minutes: 9)),
                    dispatchId: 'DSP-BREACH-${scenario.updateId}',
                    clientId: 'CLIENT-DEMO',
                    regionId: 'REGION-GAUTENG',
                    siteId: 'SITE-DEMO',
                  ),
                  DecisionCreated(
                    eventId:
                        'decision-telegram-breach-closed-${scenario.updateId}',
                    sequence: 2,
                    version: 1,
                    occurredAt: now.subtract(const Duration(minutes: 18)),
                    dispatchId: 'DSP-BREACH-CLOSED-${scenario.updateId}',
                    clientId: 'CLIENT-DEMO',
                    regionId: 'REGION-GAUTENG',
                    siteId: 'SITE-DEMO',
                  ),
                  IncidentClosed(
                    eventId: 'closed-telegram-breach-${scenario.updateId}',
                    sequence: 3,
                    version: 1,
                    occurredAt: now.subtract(const Duration(minutes: 6)),
                    dispatchId: 'DSP-BREACH-CLOSED-${scenario.updateId}',
                    resolutionType: 'all_clear',
                    clientId: 'CLIENT-DEMO',
                    regionId: 'REGION-GAUTENG',
                    siteId: 'SITE-DEMO',
                  ),
                ],
                updateId: scenario.updateId,
                sentAtUtc: _clientsQuickActionSentAtUtc(22, 52),
                chatType: 'private',
                expected: <String>[
                  'Unresolved incidents in Demo:',
                  'INC-DSP-BREACH-${scenario.updateId}',
                ],
                forbidden: const <String>[],
              ),
            for (final scenario in <({String prompt, int updateId})>[
              (prompt: 'Fire status', updateId: 90321),
              (prompt: 'Medical status', updateId: 90322),
              (prompt: 'Police status', updateId: 90323),
              (prompt: 'Ambulance status', updateId: 90324),
              (prompt: 'Fire update', updateId: 90325),
              (prompt: 'Medical?', updateId: 90326),
              (prompt: 'Police here', updateId: 90327),
              (prompt: 'Ambulnce status', updateId: 90328),
              (prompt: 'Is there a fire?', updateId: 90329),
            ])
              (
                prompts: <String>[scenario.prompt],
                events: <DispatchEvent>[
                  DecisionCreated(
                    eventId:
                        'decision-telegram-emergency-open-${scenario.updateId}',
                    sequence: 1,
                    version: 1,
                    occurredAt: now.subtract(const Duration(minutes: 7)),
                    dispatchId: 'DSP-EMERGENCY-${scenario.updateId}',
                    clientId: 'CLIENT-DEMO',
                    regionId: 'REGION-GAUTENG',
                    siteId: 'SITE-DEMO',
                  ),
                ],
                updateId: scenario.updateId,
                sentAtUtc: _clientsQuickActionSentAtUtc(22, 58),
                chatType: 'private',
                expected: <String>[
                  'Unresolved incidents in Demo:',
                  'INC-DSP-EMERGENCY-${scenario.updateId}',
                ],
                forbidden: const <String>[],
              ),
            (
              prompts: const <String>['Any fire issues tonight'],
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'decision-telegram-mixed-tonight-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: latestInWindow.toUtc(),
                  dispatchId: 'DSP-MIXED-TONIGHT',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
                DecisionCreated(
                  eventId: 'decision-telegram-mixed-tonight-old',
                  sequence: 2,
                  version: 1,
                  occurredAt: start
                      .subtract(const Duration(minutes: 12))
                      .toUtc(),
                  dispatchId: 'DSP-MIXED-OLD',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
              ],
              updateId: 90331,
              sentAtUtc: latestInWindow.toUtc(),
              chatType: 'private',
              expected: const <String>[
                "Tonight's incidents for Demo:",
                'DSP-MIXED-TONIGHT',
              ],
              forbidden: const <String>['DSP-MIXED-OLD'],
            ),
            (
              prompts: const <String>['Any medical incidents here'],
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'decision-telegram-mixed-unresolved-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 6)),
                  dispatchId: 'DSP-MIXED-UNRESOLVED',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
              ],
              updateId: 90332,
              sentAtUtc: _clientsQuickActionSentAtUtc(23, 3),
              chatType: 'private',
              expected: const <String>[
                'Unresolved incidents in Demo:',
                'INC-DSP-MIXED-UNRESOLVED',
              ],
              forbidden: const <String>[],
            ),
            (
              prompts: const <String>['Police activity at MS Vallee tonight?'],
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'decision-telegram-mixed-scoped-tonight-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: latestInWindow.toUtc(),
                  dispatchId: 'DSP-MIXED-SCOPED-TONIGHT',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
                DecisionCreated(
                  eventId: 'decision-telegram-mixed-scoped-tonight-old',
                  sequence: 2,
                  version: 1,
                  occurredAt: start
                      .subtract(const Duration(minutes: 8))
                      .toUtc(),
                  dispatchId: 'DSP-MIXED-SCOPED-OLD',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
              ],
              updateId: 90333,
              sentAtUtc: latestInWindow.toUtc(),
              chatType: 'private',
              expected: const <String>[
                "Tonight's incidents for Demo:",
                'DSP-MIXED-SCOPED-TONIGHT',
              ],
              forbidden: const <String>['DSP-MIXED-SCOPED-OLD'],
            ),
            (
              prompts: const <String>[
                'there is a fire in the building',
                'Do we have any breaches?',
              ],
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'decision-telegram-escalated-breach-open',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 5)),
                  dispatchId: 'DSP-ESCALATED-BREACH',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
              ],
              updateId: 90341,
              sentAtUtc: null,
              chatType: 'private',
              expected: const <String>[
                'Unresolved incidents in Demo:',
                'INC-DSP-ESCALATED-BREACH',
              ],
              forbidden: const <String>['This is already escalated for'],
            ),
            (
              prompts: const <String>['need police now', 'Is there a fire?'],
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'decision-telegram-escalated-emergency-open',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 4)),
                  dispatchId: 'DSP-ESCALATED-EMERGENCY',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
              ],
              updateId: 90351,
              sentAtUtc: null,
              chatType: 'private',
              expected: const <String>[
                'Unresolved incidents in Demo:',
                'INC-DSP-ESCALATED-EMERGENCY',
              ],
              forbidden: const <String>['This is already escalated for'],
            ),
            (
              prompts: const <String>['Show last patrol report for Guard001'],
              events: <DispatchEvent>[
                PatrolCompleted(
                  eventId: 'patrol-telegram-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 24)),
                  guardId: 'Guard001',
                  routeId: 'NORTH-PERIMETER',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                  durationSeconds: 18 * 60,
                ),
              ],
              updateId: 9004,
              sentAtUtc: _clientsQuickActionSentAtUtc(22, 41),
              chatType: 'private',
              expected: const <String>[
                'Last patrol report for Guard001 in Demo:',
                'Route North Perimeter',
                'Duration 18 min',
              ],
              forbidden: const <String>[],
            ),
            (
              prompts: const <String>['Draft a client update'],
              events: const <DispatchEvent>[],
              updateId: 9019,
              sentAtUtc: _clientsQuickActionSentAtUtc(23, 7),
              chatType: 'private',
              expected: const <String>[
                'Action stage is not allowed for client.',
                'This room supports read-only ONYX checks. Client updates are drafted from Command or Admin.',
                'Try: "check cameras", "give me an update", or "what changed tonight".',
              ],
              forbidden: const <String>[],
            ),
            (
              prompts: const <String>['Check tonights breaches'],
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'decision-telegram-tonight-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: latestInWindow.toUtc(),
                  dispatchId: 'DSP-551',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
                DecisionCreated(
                  eventId: 'decision-telegram-tonight-old',
                  sequence: 2,
                  version: 1,
                  occurredAt: start
                      .subtract(const Duration(minutes: 12))
                      .toUtc(),
                  dispatchId: 'DSP-OLD',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
              ],
              updateId: 9005,
              sentAtUtc: latestInWindow.toUtc(),
              chatType: 'group',
              expected: const <String>[
                "Tonight's incidents for Demo:",
                'DSP-551',
              ],
              forbidden: const <String>['DSP-OLD'],
            ),
            (
              prompts: const <String>['What changed tonight'],
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'decision-telegram-changed-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: latestInWindow.toUtc(),
                  dispatchId: 'DSP-552',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
                DecisionCreated(
                  eventId: 'decision-telegram-changed-old',
                  sequence: 2,
                  version: 1,
                  occurredAt: start
                      .subtract(const Duration(minutes: 12))
                      .toUtc(),
                  dispatchId: 'DSP-OLD',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                ),
              ],
              updateId: 9006,
              sentAtUtc: latestInWindow.toUtc(),
              chatType: 'group',
              expected: const <String>[
                "Tonight's incidents for Demo:",
                'DSP-552',
              ],
              forbidden: const <String>['DSP-OLD'],
            ),
          ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        late final String sentTranscript;
        if (scenario.prompts.length == 1) {
          final bridge = await pumpClientTelegramPromptThroughRoute(
            tester,
            appKey: ValueKey(
              'clients-telegram-incident-read-matrix-app-$index',
            ),
            prompt: scenario.prompts.single,
            updateId: scenario.updateId,
            sentAtUtc: scenario.sentAtUtc,
            operationalNowUtc: now,
            chatType: scenario.chatType,
            initialStoreEventsOverride: scenario.events,
          );
          sentTranscript = bridge.sentMessages
              .map((message) => message.text)
              .join('\n---\n');
        } else {
          sentTranscript = await sendClientTelegramConversationThroughRoute(
            tester,
            appKey: ValueKey(
              'clients-telegram-incident-read-matrix-conversation-$index',
            ),
            prompts: scenario.prompts,
            firstUpdateId: scenario.updateId,
            operationalNowUtc: now,
            chatType: scenario.chatType,
            initialStoreEventsOverride: scenario.events,
          );
        }

        for (final text in scenario.expected) {
          expect(
            sentTranscript,
            contains(text),
            reason: scenario.prompts.join(' / '),
          );
        }
        for (final text in scenario.forbidden) {
          expect(
            sentTranscript,
            isNot(contains(text)),
            reason: scenario.prompts.join(' / '),
          );
        }
      }
    },
  );

  testWidgets('onyx app keeps the deterministic partner read matrix stable', (
    tester,
  ) async {
    final now = _clientsMatrixNowUtc();
    final localNow = _clientsScenarioLocalNow();
    final end = DateTime(localNow.year, localNow.month, localNow.day, 6);
    final start = DateTime(
      end.year,
      end.month,
      end.day,
    ).subtract(const Duration(days: 1)).add(const Duration(hours: 18));

    final cases =
        <
          ({
            String prompt,
            List<DispatchEvent> events,
            int updateId,
            DateTime? sentAtUtc,
            List<String> expected,
            List<String> forbidden,
          })
        >[
          (
            prompt: 'Show dispatches today',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'partner-command-decision-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 11)),
                dispatchId: 'DSP-510',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
              ),
            ],
            updateId: 9011,
            sentAtUtc: _clientsQuickActionSentAtUtc(22, 49),
            expected: const <String>[
              'Today\'s dispatches for Demo:',
              'DSP-510',
            ],
            forbidden: const <String>[],
          ),
          (
            prompt: 'Check status of Guard001',
            events: <DispatchEvent>[
              PatrolCompleted(
                eventId: 'partner-guard-status-patrol-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 19)),
                guardId: 'Guard001',
                routeId: 'NORTH-PERIMETER',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                durationSeconds: 17 * 60,
              ),
            ],
            updateId: 9012,
            sentAtUtc: _clientsQuickActionSentAtUtc(22, 51),
            expected: const <String>[
              'Latest guard status for Guard001 in Demo:',
              'Route North Perimeter',
              'Duration 17 min',
            ],
            forbidden: const <String>[],
          ),
          (
            prompt: 'Show last patrol report for Guard001',
            events: <DispatchEvent>[
              PatrolCompleted(
                eventId: 'partner-patrol-report-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 23)),
                guardId: 'Guard001',
                routeId: 'NORTH-PERIMETER',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
                durationSeconds: 16 * 60,
              ),
            ],
            updateId: 9013,
            sentAtUtc: _clientsQuickActionSentAtUtc(22, 53),
            expected: const <String>[
              'Last patrol report for Guard001 in Demo:',
              'Route North Perimeter',
              'Duration 16 min',
            ],
            forbidden: const <String>[],
          ),
          (
            prompt: 'Draft a client update',
            events: const <DispatchEvent>[],
            updateId: 9020,
            sentAtUtc: _clientsQuickActionSentAtUtc(23, 9),
            expected: const <String>[
              'Action stage is not allowed for supervisor.',
              'This room supports scoped reads and dispatch replies. Client updates are still drafted from Command or Admin.',
              'Try: "show dispatches today", "check status of Guard001", or "show incidents last night".',
            ],
            forbidden: const <String>[],
          ),
          (
            prompt: 'Show incidents last night',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'partner-last-night-1',
                sequence: 1,
                version: 1,
                occurredAt: start
                    .add(const Duration(hours: 1, minutes: 6))
                    .toUtc(),
                dispatchId: 'DSP-LN1',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
              ),
              DecisionCreated(
                eventId: 'partner-last-night-2',
                sequence: 2,
                version: 1,
                occurredAt: start
                    .add(const Duration(hours: 4, minutes: 32))
                    .toUtc(),
                dispatchId: 'DSP-LN2',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
              ),
              DecisionCreated(
                eventId: 'partner-last-night-outside',
                sequence: 3,
                version: 1,
                occurredAt: start.subtract(const Duration(minutes: 24)).toUtc(),
                dispatchId: 'DSP-OLD',
                clientId: 'CLIENT-DEMO',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-DEMO',
              ),
            ],
            updateId: 9014,
            sentAtUtc: _clientsQuickActionSentAtUtc(22, 55),
            expected: const <String>[
              "Last night's incidents for Demo:",
              '• Count:',
              '• Latest:',
            ],
            forbidden: const <String>['INC-DSP-OLD'],
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final bridge = await pumpPartnerTelegramPromptThroughRoute(
        tester,
        appKey: ValueKey('clients-telegram-partner-read-matrix-app-$index'),
        prompt: scenario.prompt,
        updateId: scenario.updateId,
        sentAtUtc: scenario.sentAtUtc,
        operationalNowUtc: now,
        initialStoreEventsOverride: scenario.events,
      );
      final sentTranscript = telegramTranscriptFromMessages(
        bridge.sentMessages,
      );

      for (final text in scenario.expected) {
        expect(sentTranscript, contains(text), reason: scenario.prompt);
      }
      for (final text in scenario.forbidden) {
        expect(sentTranscript, isNot(contains(text)), reason: scenario.prompt);
      }
    }
  });

  testWidgets(
    'onyx app keeps camera zone labels deterministic in monitoring narratives',
    (tester) async {
      final customNow = _clientsMatrixNowUtc();
      final defaultNow = _clientsMatrixNowUtc();

      final cases =
          <
            ({
              Key appKey,
              String prompt,
              int updateId,
              DateTime sentAtUtc,
              String siteId,
              List<MonitoringShiftScopeConfig> monitoringConfigs,
              List<DvrScopeConfig> dvrConfigs,
              List<DispatchEvent> events,
              List<String> expected,
            })
          >[
            (
              appKey: const ValueKey('clients-telegram-zone-aware-app'),
              prompt: 'Details',
              updateId: 9002,
              sentAtUtc: _clientsQuickActionSentAtUtc(9, 4),
              siteId: 'WTF-MAIN',
              monitoringConfigs: const <MonitoringShiftScopeConfig>[
                MonitoringShiftScopeConfig(
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'WTF-MAIN',
                  schedule: MonitoringShiftSchedule(
                    enabled: true,
                    startHour: 18,
                    startMinute: 0,
                    endHour: 18,
                    endMinute: 0,
                  ),
                ),
              ],
              dvrConfigs: const <DvrScopeConfig>[
                DvrScopeConfig(
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'WTF-MAIN',
                  provider: 'hikvision_dvr_monitor_only',
                  eventsUri: null,
                  authMode: 'digest',
                  username: 'admin',
                  password: 'secret',
                  bearerToken: '',
                  cameraLabels: <String, String>{
                    'channel-13': 'Front Yard',
                    'channel-12': 'Back Yard',
                    'channel-6': 'Driveway',
                  },
                ),
              ],
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'evt-zone-aware-13',
                  sequence: 1,
                  version: 1,
                  occurredAt: customNow.subtract(const Duration(minutes: 1)),
                  intelligenceId: 'zone-aware-13',
                  provider: 'hikvision_dvr_monitor_only',
                  sourceType: 'dvr',
                  externalId: 'ext-zone-aware-13',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'WTF-MAIN',
                  cameraId: 'channel-13',
                  objectLabel: 'person',
                  objectConfidence: 0.9,
                  headline: 'Zone-aware movement',
                  summary: 'Front-yard movement detected.',
                  riskScore: 68,
                  snapshotUrl: null,
                  canonicalHash: 'hash-zone-aware-13',
                ),
                IntelligenceReceived(
                  eventId: 'evt-zone-aware-12',
                  sequence: 2,
                  version: 1,
                  occurredAt: customNow.subtract(const Duration(minutes: 2)),
                  intelligenceId: 'zone-aware-12',
                  provider: 'hikvision_dvr_monitor_only',
                  sourceType: 'dvr',
                  externalId: 'ext-zone-aware-12',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'WTF-MAIN',
                  cameraId: 'channel-12',
                  objectLabel: 'person',
                  objectConfidence: 0.9,
                  headline: 'Zone-aware movement',
                  summary: 'Back-yard movement detected.',
                  riskScore: 68,
                  snapshotUrl: null,
                  canonicalHash: 'hash-zone-aware-12',
                ),
                IntelligenceReceived(
                  eventId: 'evt-zone-aware-6',
                  sequence: 3,
                  version: 1,
                  occurredAt: customNow.subtract(const Duration(minutes: 3)),
                  intelligenceId: 'zone-aware-6',
                  provider: 'hikvision_dvr_monitor_only',
                  sourceType: 'dvr',
                  externalId: 'ext-zone-aware-6',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'WTF-MAIN',
                  cameraId: 'channel-6',
                  objectLabel: 'vehicle',
                  objectConfidence: 0.9,
                  headline: 'Zone-aware movement',
                  summary: 'Driveway movement detected.',
                  riskScore: 68,
                  snapshotUrl: null,
                  canonicalHash: 'hash-zone-aware-6',
                ),
              ],
              expected: const <String>[
                'Summary: Recent camera review saw 2 person signals across Back Yard and Front Yard, plus 1 vehicle signal across Driveway.',
                'Latest signal: Front Yard',
                'Review note: Front-yard movement detected.',
                'Assessment: distributed movement across multiple cameras',
              ],
            ),
            (
              appKey: const ValueKey(
                'clients-telegram-default-vallee-labels-app',
              ),
              prompt: 'Details',
              updateId: 9003,
              sentAtUtc: defaultNow,
              siteId: 'SITE-DEMO',
              monitoringConfigs: const <MonitoringShiftScopeConfig>[],
              dvrConfigs: const <DvrScopeConfig>[],
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'evt-default-vallee-13',
                  sequence: 1,
                  version: 1,
                  occurredAt: defaultNow.subtract(const Duration(minutes: 1)),
                  intelligenceId: 'default-vallee-13',
                  provider: 'hikvision_dvr_monitor_only',
                  sourceType: 'dvr',
                  externalId: 'ext-default-vallee-13',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                  cameraId: 'channel-13',
                  objectLabel: 'person',
                  objectConfidence: 0.9,
                  headline: 'Default Vallee movement',
                  summary: 'Front-yard movement detected.',
                  riskScore: 68,
                  snapshotUrl: null,
                  canonicalHash: 'hash-default-vallee-13',
                ),
                IntelligenceReceived(
                  eventId: 'evt-default-vallee-12',
                  sequence: 2,
                  version: 1,
                  occurredAt: defaultNow.subtract(const Duration(minutes: 2)),
                  intelligenceId: 'default-vallee-12',
                  provider: 'hikvision_dvr_monitor_only',
                  sourceType: 'dvr',
                  externalId: 'ext-default-vallee-12',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                  cameraId: 'channel-12',
                  objectLabel: 'person',
                  objectConfidence: 0.9,
                  headline: 'Default Vallee movement',
                  summary: 'Back-yard movement detected.',
                  riskScore: 68,
                  snapshotUrl: null,
                  canonicalHash: 'hash-default-vallee-12',
                ),
                IntelligenceReceived(
                  eventId: 'evt-default-vallee-6',
                  sequence: 3,
                  version: 1,
                  occurredAt: defaultNow.subtract(const Duration(minutes: 3)),
                  intelligenceId: 'default-vallee-6',
                  provider: 'hikvision_dvr_monitor_only',
                  sourceType: 'dvr',
                  externalId: 'ext-default-vallee-6',
                  clientId: 'CLIENT-DEMO',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-DEMO',
                  cameraId: 'channel-6',
                  objectLabel: 'vehicle',
                  objectConfidence: 0.9,
                  headline: 'Default Vallee movement',
                  summary: 'Driveway movement detected.',
                  riskScore: 68,
                  snapshotUrl: null,
                  canonicalHash: 'hash-default-vallee-6',
                ),
              ],
              expected: const <String>[
                'Summary: Recent camera review saw 2 person signals across Back Yard and Front Yard, plus 1 vehicle signal across Driveway.',
                'Latest signal: Front Yard',
                'Review note: Front-yard movement detected.',
              ],
            ),
          ];

      for (final scenario in cases) {
        final bridge = await pumpClientTelegramPromptThroughRoute(
          tester,
          appKey: scenario.appKey,
          prompt: scenario.prompt,
          updateId: scenario.updateId,
          sentAtUtc: scenario.sentAtUtc,
          operationalNowUtc: scenario.siteId == 'WTF-MAIN'
              ? customNow
              : defaultNow,
          siteId: scenario.siteId,
          monitoringShiftScopeConfigsOverride: scenario.monitoringConfigs,
          dvrScopeConfigsOverride: scenario.dvrConfigs,
          initialStoreEventsOverride: scenario.events,
        );

        final quickActionResponse = bridge.sentMessages
            .map((message) => message.text)
            .firstWhere((text) => text.contains('Review note:'));
        for (final text in scenario.expected) {
          expect(quickActionResponse, contains(text));
        }
      }
    },
  );

  testWidgets(
    'onyx app keeps client lane delivery telemetry deterministic across default and scoped routes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var retryTriggeredCount = 0;

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          onClientPushRetryTriggered: () {
            retryTriggeredCount += 1;
          },
        ),
      );
      await tester.pumpAndSettle();
      await _openClientsDetailedWorkspaceIfPresent(tester);

      final retryAction = tester.widget<InkWell>(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
      );
      expect(retryAction.onTap, isNotNull);
      retryAction.onTap!.call();
      await tester.pumpAndSettle();

      expect(retryTriggeredCount, 1);

      SharedPreferences.setMockInitialValues({});

      await seedDefaultValleeQueuedDelivery(
        messageKey: 'test-sms-fallback-1',
        occurredAtUtc: _clientsRouteOccurredAtUtc(45),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          telegramBridgeServiceOverride: const _ConfiguredTelegramBridgeStub(),
          smsDeliveryServiceOverride: const _SuccessfulSmsDeliveryStub(),
          activeContactPhonesResolverOverride: (clientId, siteId) async =>
              const <String>['+27825550441', '+27834440442'],
        ),
      );
      await tester.pumpAndSettle();
      await _openClientsDetailedWorkspaceIfPresent(tester);

      final retryForFallback = tester.widget<InkWell>(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
      );
      expect(retryForFallback.onTap, isNotNull);
      retryForFallback.onTap!.call();
      await tester.pumpAndSettle();

      await pumpAdminRouteApp(tester, key: const ValueKey('admin-app'));
      await openAdminClientCommsAudit(tester);

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('LATEST SMS FALLBACK'), findsWidgets);
      expect(
        find.textContaining(
          'BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsWidgets,
      );

      SharedPreferences.setMockInitialValues({});

      await seedDefaultValleeQueuedDelivery(
        messageKey: 'test-unscoped-client-fallback-1',
        occurredAtUtc: _clientsRouteOccurredAtUtc(46),
      );

      final unscopedBridge = _RecordingTelegramBridgeStub();
      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-unscoped-telegram-fallback-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          telegramBridgeServiceOverride: unscopedBridge,
          telegramChatIdOverride: 'test-client-chat',
          smsDeliveryServiceOverride: const _SuccessfulSmsDeliveryStub(),
          activeContactPhonesResolverOverride: (clientId, siteId) async =>
              const <String>['+27825550441', '+27834440442'],
        ),
      );
      await tester.pumpAndSettle();
      await _openClientsDetailedWorkspaceIfPresent(tester);

      final retryForUnscopedFallback = tester.widget<InkWell>(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
      );
      expect(retryForUnscopedFallback.onTap, isNotNull);
      retryForUnscopedFallback.onTap!.call();
      await tester.pumpAndSettle();

      expect(
        unscopedBridge.sentMessages,
        isEmpty,
        reason: 'unscoped fallback chat must not receive queued client pushes',
      );

      SharedPreferences.setMockInitialValues({});

      await seedDefaultValleeVoipAndSmsFallbackHistory();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-history-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();
      await _openClientsDetailedWorkspaceIfPresent(tester);

      expect(
        find.textContaining(
          '13:05 UTC • voip staged • queue:1 • Asterisk staged a call for Vallee command desk.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '13:04 UTC • sms fallback sent • queue:2 • BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsOneWidget,
      );

      SharedPreferences.setMockInitialValues({});

      await seedWaterfallScopedVoipFailurePushSync(
        occurredAtUtc: _clientsOffScopeSyncOccurredAtUtc(6),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-scope-isolation-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Client Ops App'), findsOneWidget);
      expect(
        find.textContaining(
          'VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsNothing,
      );

      final scenarios =
          <
            ({
              ValueKey<String> appKey,
              List<String> expectedContainedTexts,
              List<String> expectedExactTexts,
              String seedKind,
            })
          >[
            (
              seedKind: 'scopedState',
              appKey: const ValueKey('clients-off-scope-state-app'),
              expectedExactTexts: const <String>[],
              expectedContainedTexts: <String>[],
            ),
            (
              seedKind: 'queueState',
              appKey: const ValueKey('clients-off-scope-queue-app'),
              expectedExactTexts: <String>['Scoped queue update', 'Delivered'],
              expectedContainedTexts: <String>[
                'Waterfall lane is holding this queued update for client review.',
              ],
            ),
            (
              seedKind: 'telegramHealth',
              appKey: const ValueKey('clients-off-scope-telegram-health-app'),
              expectedExactTexts: <String>[
                'Telegram: BLOCKED',
                'Telegram fallback is active.',
              ],
              expectedContainedTexts: <String>[
                'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
              ],
            ),
          ];

      for (final scenario in scenarios) {
        SharedPreferences.setMockInitialValues({});

        switch (scenario.seedKind) {
          case 'scopedState':
            await seedWaterfallScopedVoipFailurePushSync(
              occurredAtUtc: _clientsOffScopeSyncOccurredAtUtc(7),
              retryCount: 1,
              backendProbeOccurredAtUtc: _clientsOffScopeSyncOccurredAtUtc(8),
            );
            break;
          case 'queueState':
            const messageKey = 'route-scope-queue-1';
            await seedWaterfallQueuedDelivery(
              messageKey: messageKey,
              occurredAtUtc: _clientsOffScopeOccurredAtUtc(45),
              title: 'Scoped queue update',
              body:
                  'Waterfall lane is holding this queued update for client review.',
              status: ClientPushDeliveryStatus.acknowledged,
              acknowledgedAtUtc: _clientsOffScopeOccurredAtUtc(40),
            );
            break;
          case 'telegramHealth':
            await seedWaterfallTelegramBlockedPushSyncAt(
              occurredAtUtc: _clientsOffScopeSyncOccurredAtUtc(12),
            );
            break;
        }

        await pumpOffScopeClientLane(tester, appKey: scenario.appKey);
        await _openClientsDetailedWorkspaceIfPresent(tester);

        expect(
          find.text('Client Ops App — CLIENT-DEMO / WTF-MAIN'),
          findsOneWidget,
        );
        for (final text in scenario.expectedExactTexts) {
          expect(find.text(text), findsWidgets);
        }
        for (final text in scenario.expectedContainedTexts) {
          expect(find.textContaining(text), findsWidgets);
        }
      }

      SharedPreferences.setMockInitialValues({});

      await pumpOffScopeClientLane(
        tester,
        appKey: const ValueKey('clients-offscope-probe-run'),
      );
      await _openClientsDetailedWorkspaceIfPresent(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('client-delivery-telemetry-run-probe')),
      );
      await tester.tap(
        find.byKey(const ValueKey('client-delivery-telemetry-run-probe')),
      );
      await tester.pumpAndSettle();

      await pumpOffScopeClientLane(
        tester,
        appKey: const ValueKey('clients-offscope-probe-restart'),
      );
      await _openClientsDetailedWorkspaceIfPresent(tester);

      expect(find.textContaining('Backend Probe: ok'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('client-delivery-telemetry-clear-probe')),
      );
      await tester.tap(
        find.byKey(const ValueKey('client-delivery-telemetry-clear-probe')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Clear Probe History?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      await pumpOffScopeClientLane(
        tester,
        appKey: const ValueKey('clients-offscope-probe-cleared'),
      );
      await _openClientsDetailedWorkspaceIfPresent(tester);

      expect(find.textContaining('Backend Probe: idle'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app persists push-sync fallback even when the clients route is disposed mid-retry',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await seedDefaultValleeQueuedDelivery(
        messageKey: 'test-disposed-mid-retry-1',
        occurredAtUtc: _clientsRouteOccurredAtUtc(47),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-disposed-mid-retry-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          telegramBridgeServiceOverride:
              const _DelayedFailingTelegramBridgeStub(),
          smsDeliveryServiceOverride: const _SuccessfulSmsDeliveryStub(),
          activeContactPhonesResolverOverride: (clientId, siteId) async =>
              const <String>['+27825550441', '+27834440442'],
        ),
      );
      await tester.pumpAndSettle();
      await _openClientsDetailedWorkspaceIfPresent(tester);

      final retryAction = tester.widget<InkWell>(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
      );
      expect(retryAction.onTap, isNotNull);
      retryAction.onTap!.call();
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-disposed-mid-retry-audit-app'),
      );
      await openAdminClientCommsAudit(tester);

      expect(find.text('LATEST SMS FALLBACK'), findsWidgets);
      expect(
        find.textContaining(
          'BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app persists sms fallback when the clients route is disposed before sms delivery completes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await seedDefaultValleeQueuedDelivery(
        messageKey: 'test-disposed-mid-sms-fallback-1',
        occurredAtUtc: _clientsRouteOccurredAtUtc(48),
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-disposed-mid-sms-fallback-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          telegramBridgeServiceOverride:
              const _DelayedFailingTelegramBridgeStub(),
          smsDeliveryServiceOverride: const _DelayedSuccessfulSmsDeliveryStub(),
          activeContactPhonesResolverOverride: (clientId, siteId) async =>
              const <String>['+27825550441', '+27834440442'],
        ),
      );
      await tester.pumpAndSettle();
      await _openClientsDetailedWorkspaceIfPresent(tester);

      final retryAction = tester.widget<InkWell>(
        find.byKey(const ValueKey('clients-retry-push-sync-action')),
      );
      expect(retryAction.onTap, isNotNull);
      retryAction.onTap!.call();
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-disposed-mid-sms-fallback-audit-app'),
      );
      await openAdminClientCommsAudit(tester);

      expect(find.text('LATEST SMS FALLBACK'), findsWidgets);
      expect(
        find.textContaining(
          'BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app persists backend probe results when the clients route is disposed before probe persistence completes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final previousStore = SharedPreferencesStorePlatform.instance;
      final delayedStore = _DelayedClientPushSyncStateStore.withData(
        const <String, Object>{},
      );
      SharedPreferencesStorePlatform.instance = delayedStore;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previousStore;
      });
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpOffScopeClientLane(
        tester,
        appKey: const ValueKey('clients-disposed-mid-backend-probe-app'),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('client-delivery-telemetry-run-probe')),
      );
      await tester.tap(
        find.byKey(const ValueKey('client-delivery-telemetry-run-probe')),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));

      final persistence = await DispatchPersistenceService.create();
      final restored = await persistence.readScopedClientAppPushSyncState(
        clientId: 'CLIENT-DEMO',
        siteId: 'WTF-MAIN',
      );

      expect(restored.backendProbeStatusLabel, 'ok');
      expect(restored.backendProbeLastRunAtUtc, isNotNull);
      expect(restored.backendProbeFailureReason, isNull);
    },
  );

  testWidgets(
    'onyx app keeps off-scope routed lane routing, comms detail, and updates deterministic across client and admin surfaces',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scenarios =
          <
            ({
              String adminAppKey,
              String adminAnchor,
              String clientAppKey,
              List<String> adminContainedTexts,
              List<String> adminExactTexts,
              List<String> clientContainedTexts,
              List<String> clientExactTexts,
              String seedKind,
            })
          >[
            (
              seedKind: 'pushPressure',
              adminAppKey: 'admin-to-client-push-pressure-admin-app',
              adminAnchor: 'LATEST PUSH DETAIL',
              clientAppKey: 'admin-to-client-push-pressure-client-app',
              adminExactTexts: <String>['Push FAILED', '1 push item queued'],
              adminContainedTexts: <String>[
                'Waterfall push sync needs operator review before retry.',
              ],
              clientExactTexts: const <String>[],
              clientContainedTexts: const <String>[],
            ),
            (
              seedKind: 'telegramHealth',
              adminAppKey: 'admin-to-client-telegram-health-admin-app',
              adminAnchor: '',
              clientAppKey: 'admin-to-client-telegram-health-client-app',
              adminExactTexts: <String>['Telegram BLOCKED'],
              adminContainedTexts: <String>[
                'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
              ],
              clientExactTexts: const <String>[],
              clientContainedTexts: <String>[
                'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
              ],
            ),
            (
              seedKind: 'smsFallback',
              adminAppKey: 'admin-to-client-sms-fallback-admin-app',
              adminAnchor: 'LATEST SMS FALLBACK',
              clientAppKey: 'admin-to-client-sms-fallback-client-app',
              adminExactTexts: <String>['LATEST SMS FALLBACK'],
              adminContainedTexts: <String>[
                'BulkSMS reached 2/2 contacts after telegram target failure.',
              ],
              clientExactTexts: const <String>[],
              clientContainedTexts: <String>[
                'BulkSMS reached 2/2 contacts after telegram target failure.',
              ],
            ),
            (
              seedKind: 'voipHistory',
              adminAppKey: 'admin-to-client-voip-history-admin-app',
              adminAnchor: 'LATEST VOIP STAGE',
              clientAppKey: 'admin-to-client-voip-history-client-app',
              adminExactTexts: <String>['LATEST VOIP STAGE'],
              adminContainedTexts: <String>[
                'Asterisk staged a call for Waterfall command desk.',
              ],
              clientExactTexts: const <String>[],
              clientContainedTexts: <String>[
                'Asterisk staged a call for Waterfall command desk.',
              ],
            ),
          ];

      for (final scenario in scenarios) {
        await prepareAdminRouteTest(tester);

        switch (scenario.seedKind) {
          case 'pushPressure':
            await seedWaterfallPushPressure(
              messageKey: 'waterfall-admin-to-client-push-1',
              occurredAtUtc: _clientsOffScopeSyncOccurredAtUtc(16),
            );
            break;
          case 'telegramHealth':
            await seedWaterfallTelegramBlockedPushSync();
            break;
          case 'smsFallback':
            await seedWaterfallSmsFallbackPushSync(
              occurredAtUtc: _clientsOffScopeSyncOccurredAtUtc(23),
            );
            break;
          case 'voipHistory':
            await seedWaterfallVoipStagePushSync(
              occurredAtUtc: _clientsOffScopeSyncOccurredAtUtc(24),
            );
            break;
        }

        await pumpAdminRouteApp(tester, key: ValueKey(scenario.adminAppKey));
        if (scenario.adminAnchor.isEmpty) {
          await openAdminClientCommsAudit(tester);
        } else {
          await openAdminSystemAnchor(tester, scenario.adminAnchor);
        }

        expect(find.text('Client Comms Audit'), findsOneWidget);
        for (final text in scenario.adminExactTexts) {
          expect(find.text(text), findsWidgets);
        }
        for (final text in scenario.adminContainedTexts) {
          expect(find.textContaining(text), findsWidgets);
        }

        await pumpOffScopeClientLane(
          tester,
          appKey: ValueKey(scenario.clientAppKey),
        );
        await _openClientsDetailedWorkspaceIfPresent(tester);

        expect(
          find.text('Client Ops App — CLIENT-DEMO / WTF-MAIN'),
          findsOneWidget,
        );
        for (final text in scenario.clientExactTexts) {
          expect(find.text(text), findsWidgets);
        }
        for (final text in scenario.clientContainedTexts) {
          expect(find.textContaining(text), findsWidgets);
        }
      }

      SharedPreferences.setMockInitialValues({});

      final persistence = await DispatchPersistenceService.create();
      final scopedConversation = ScopedSharedPrefsClientConversationRepository(
        persistence: persistence,
        clientId: 'CLIENT-DEMO',
        siteId: 'WTF-MAIN',
      );
      await scopedConversation.saveMessages(<ClientAppMessage>[
        ClientAppMessage(
          author: '@waterfall_resident',
          body:
              'Please confirm whether the Waterfall response team has already arrived.',
          occurredAt: _clientsRouteOccurredAtUtc(43),
          roomKey: 'Residents',
          viewerRole: ClientAppViewerRole.client.name,
          incidentStatusLabel: 'Update',
          messageSource: 'telegram',
          messageProvider: 'telegram',
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-off-scope-ask-lane-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Client Ops App — CLIENT-DEMO / WTF-MAIN'),
        findsOneWidget,
      );
      expect(
        find.text('Client Ops App — CLIENT-DEMO / SITE-DEMO'),
        findsNothing,
      );

      SharedPreferences.setMockInitialValues({});

      await seedWaterfallQueuedDelivery(
        messageKey: 'offscope-sms-fallback-1',
        occurredAtUtc: _clientsOffScopeSyncOccurredAtUtc(11),
        body: 'This queued client update belongs to the Waterfall lane.',
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('clients-offscope-retry-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.clients,
          initialClientLaneClientIdOverride: 'CLIENT-DEMO',
          initialClientLaneSiteIdOverride: 'WTF-MAIN',
          appModeOverride: OnyxAppMode.client,
          telegramBridgeServiceOverride: const _ConfiguredTelegramBridgeStub(),
          smsDeliveryServiceOverride: const _SuccessfulSmsDeliveryStub(),
          activeContactPhonesResolverOverride: (clientId, siteId) async =>
              clientId == 'CLIENT-DEMO' && siteId == 'WTF-MAIN'
              ? const <String>['+27825550441', '+27834440442']
              : const <String>[],
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('client-delivery-telemetry-retry-sync')),
      );
      await tester.tap(
        find.byKey(const ValueKey('client-delivery-telemetry-retry-sync')),
      );
      await tester.pumpAndSettle();

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-offscope-retry-audit'),
      );
      await openAdminClientCommsAudit(tester);

      expect(find.text('Cross-scope'), findsWidgets);
      expect(find.textContaining('WTF-MAIN'), findsWidgets);
      expect(find.text('LATEST SMS FALLBACK'), findsWidgets);
      expect(
        find.textContaining(
          'BulkSMS reached 2/2 contacts after telegram target failure.',
        ),
        findsWidgets,
      );

      final updateScenarios = <({String scenarioKind, String visibleText, String absentText})>[
        (
          scenarioKind: 'ack',
          visibleText: 'Delivered',
          absentText: 'Delivered',
        ),
        (
          scenarioKind: 'clientMessage',
          visibleText:
              'Waterfall lane manual update: resident confirmed access gate is clear.',
          absentText:
              'Waterfall lane manual update: resident confirmed access gate is clear.',
        ),
        (
          scenarioKind: 'controlUpdate',
          visibleText:
              'Waterfall control lane update: desk has logged the resident follow-up.',
          absentText:
              'Waterfall control lane update: desk has logged the resident follow-up.',
        ),
      ];

      for (final scenario in updateScenarios) {
        SharedPreferences.setMockInitialValues({});

        switch (scenario.scenarioKind) {
          case 'ack':
            await pumpOffScopeClientLane(
              tester,
              appKey: const ValueKey('clients-off-scope-ack-run'),
              initialStoreEventsOverride: <DispatchEvent>[
                _waterfallDispatchDecision(
                  dispatchId: 'DISP-WTF-ACK-1',
                  occurredAt: _clientsOffScopeOccurredAtUtc(44),
                ),
              ],
            );

            final clientAckAction = find.widgetWithText(
              TextButton,
              'Client Ack',
            );
            await tester.ensureVisible(clientAckAction.first);
            await tester.tap(clientAckAction.first);
            await tester.pumpAndSettle();

            await pumpOffScopeClientLane(
              tester,
              appKey: const ValueKey('clients-off-scope-ack-restart'),
            );
            break;
          case 'clientMessage':
            await tester.pumpWidget(
              OnyxApp(
                key: const ValueKey('clients-off-scope-message-run'),
                supabaseReady: false,
                initialRouteOverride: OnyxRoute.clients,
                initialClientLaneClientIdOverride: 'CLIENT-DEMO',
                initialClientLaneSiteIdOverride: 'WTF-MAIN',
                appModeOverride: OnyxAppMode.client,
              ),
            );
            await tester.pumpAndSettle();

            await tester.enterText(
              find.byType(TextField).first,
              scenario.visibleText,
            );
            await tester.ensureVisible(
              find.widgetWithText(FilledButton, 'Send'),
            );
            await tester.tap(find.widgetWithText(FilledButton, 'Send'));
            await tester.pumpAndSettle();

            await tester.pumpWidget(
              OnyxApp(
                key: const ValueKey('clients-off-scope-message-restart'),
                supabaseReady: false,
                initialRouteOverride: OnyxRoute.clients,
                initialClientLaneClientIdOverride: 'CLIENT-DEMO',
                initialClientLaneSiteIdOverride: 'WTF-MAIN',
                appModeOverride: OnyxAppMode.client,
              ),
            );
            await tester.pumpAndSettle();
            break;
          case 'controlUpdate':
            await pumpClientControlSourceApp(
              tester,
              key: const ValueKey('clients-offscope-control-update-app'),
              clientId: 'CLIENT-DEMO',
              siteId: 'WTF-MAIN',
            );

            await tester.enterText(
              find.byType(TextField).first,
              scenario.visibleText,
            );
            final sendControlUpdateButton = find.widgetWithText(
              FilledButton,
              'Log Resident Update',
            );
            await tester.ensureVisible(sendControlUpdateButton);
            await tester.tap(sendControlUpdateButton);
            await tester.pumpAndSettle();

            await pumpClientControlSourceApp(
              tester,
              key: const ValueKey('clients-offscope-control-update-restart'),
              clientId: 'CLIENT-DEMO',
              siteId: 'WTF-MAIN',
            );
            break;
        }

        switch (scenario.scenarioKind) {
          case 'controlUpdate':
            expect(
              find.text('Security Desk Console — CLIENT-DEMO / WTF-MAIN'),
              findsOneWidget,
            );
            break;
          case 'ack':
          case 'clientMessage':
            expect(
              find.text('Client Ops App — CLIENT-DEMO / WTF-MAIN'),
              findsOneWidget,
            );
            break;
        }
        expect(find.textContaining(scenario.visibleText), findsWidgets);

        switch (scenario.scenarioKind) {
          case 'controlUpdate':
            await pumpClientControlSourceApp(
              tester,
              key: const ValueKey('clients-default-control-update-isolation'),
            );

            expect(
              find.text('Security Desk Console — CLIENT-DEMO / SITE-DEMO'),
              findsOneWidget,
            );
            break;
          case 'ack':
            await tester.pumpWidget(
              OnyxApp(
                key: const ValueKey('clients-default-ack-isolation'),
                supabaseReady: false,
                initialRouteOverride: OnyxRoute.clients,
                appModeOverride: OnyxAppMode.client,
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.text('Client Ops App — CLIENT-DEMO / SITE-DEMO'),
              findsOneWidget,
            );
            break;
          case 'clientMessage':
            await tester.pumpWidget(
              OnyxApp(
                key: const ValueKey('clients-default-message-isolation'),
                supabaseReady: false,
                initialRouteOverride: OnyxRoute.clients,
                appModeOverride: OnyxAppMode.client,
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.text('Client Ops App — CLIENT-DEMO / SITE-DEMO'),
              findsOneWidget,
            );
            break;
        }

        expect(find.textContaining(scenario.absentText), findsNothing);
      }
    },
  );

  testWidgets(
    'onyx app keeps client control voice and learned approval state deterministic across restart, review, and scope changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final visibleStateCases =
          <
            ({
              String anchorLabel,
              String scenarioKind,
              List<String> expectedTexts,
              List<String> absentTexts,
              ValueKey<String> appKey,
            })
          >[
            (
              scenarioKind: 'directLearned',
              appKey: const ValueKey('clients-learned-style-app'),
              anchorLabel: 'Learned approval style',
              expectedTexts: <String>[
                'Learned approvals (1)',
                'Learned approval style',
                'Control is checking the latest position now and will share the next confirmed step shortly.',
              ],
              absentTexts: const <String>[],
            ),
            (
              scenarioKind: 'directPinned',
              appKey: const ValueKey('clients-voice-app'),
              anchorLabel: 'ONYX mode: Pinned voice',
              expectedTexts: <String>[
                'Lane voice: Reassuring',
                'ONYX mode: Pinned voice',
              ],
              absentTexts: <String>['Learned approval style'],
            ),
            (
              scenarioKind: 'adminVoice',
              appKey: const ValueKey('clients-admin-voice-restart-app'),
              anchorLabel: 'ONYX mode: Pinned voice',
              expectedTexts: <String>[
                'Lane voice: Reassuring',
                'ONYX mode: Pinned voice',
              ],
              absentTexts: const <String>[],
            ),
            (
              scenarioKind: 'liveOpsVoice',
              appKey: const ValueKey('clients-live-ops-voice-restart-app'),
              anchorLabel: 'ONYX mode: Pinned voice',
              expectedTexts: <String>[
                'Lane voice: Reassuring',
                'ONYX mode: Pinned voice',
              ],
              absentTexts: const <String>[],
            ),
          ];

      for (final scenario in visibleStateCases) {
        SharedPreferences.setMockInitialValues({});

        switch (scenario.scenarioKind) {
          case 'directLearned':
            await saveTelegramAdminRuntimeState({
              ...pinnedLaneVoiceRuntimeState(profile: 'reassurance-forward'),
              ...legacyLearnedApprovalRuntimeState(const <String>[
                'Control is checking the latest position now and will share the next confirmed step shortly.',
              ]),
            });
            await pumpClientControlSourceApp(tester, key: scenario.appKey);
            break;
          case 'directPinned':
            await savePinnedLaneVoice(profile: 'reassurance-forward');
            await pumpClientControlSourceApp(tester, key: scenario.appKey);
            break;
          case 'adminVoice':
            await saveLegacyLearnedApprovalStyles(const <String>[
              'Control is checking the latest position now and will share the next confirmed step shortly.',
            ]);
            await pumpAdminRouteApp(
              tester,
              key: const ValueKey('clients-admin-voice-source-app'),
            );
            await openAdminClientCommsAudit(tester);
            final reassuringButton = find.widgetWithText(
              OutlinedButton,
              'Reassuring',
            );
            await tester.ensureVisible(reassuringButton.first);
            await tester.tap(reassuringButton.first);
            await tester.pumpAndSettle();
            await pumpClientControlSourceApp(tester, key: scenario.appKey);
            break;
          case 'liveOpsVoice':
            await pumpLiveOperationsSourceApp(
              tester,
              key: const ValueKey('clients-live-ops-voice-source-app'),
            );
            final reassuringButton = find.widgetWithText(
              OutlinedButton,
              'Reassuring',
            );
            await tester.ensureVisible(reassuringButton.first);
            await tester.tap(reassuringButton.first);
            await tester.pumpAndSettle();
            await pumpClientControlSourceApp(tester, key: scenario.appKey);
            break;
        }

        await openClientControlAnchor(tester, scenario.anchorLabel);

        for (final text in scenario.expectedTexts) {
          expect(find.textContaining(text), findsWidgets);
        }
        for (final text in scenario.absentTexts) {
          expect(find.text(text), findsNothing);
        }
      }

      final clearedStateCases =
          <
            ({
              String scenarioKind,
              List<String> expectedTexts,
              List<String> absentTexts,
              ValueKey<String> appKey,
            })
          >[
            (
              scenarioKind: 'adminClear',
              appKey: const ValueKey('clients-admin-clear-learned-restart-app'),
              expectedTexts: <String>['ONYX mode: Auto'],
              absentTexts: <String>[
                'Learned approval style',
                'Learned approvals (1)',
              ],
            ),
            (
              scenarioKind: 'liveOpsClear',
              appKey: const ValueKey(
                'clients-live-ops-clear-learned-restart-app',
              ),
              expectedTexts: <String>['ONYX mode: Auto'],
              absentTexts: <String>[
                'Learned approval style',
                'Learned approvals (1)',
              ],
            ),
          ];

      for (final scenario in clearedStateCases) {
        SharedPreferences.setMockInitialValues({});

        switch (scenario.scenarioKind) {
          case 'adminClear':
            await saveTelegramAdminRuntimeState({
              ...pendingDraftRuntimeState([
                telegramPendingDraftEntry(
                  inboundUpdateId: 801,
                  messageThreadId: 88,
                  clientId: 'CLIENT-DEMO',
                  siteId: 'SITE-DEMO',
                  sourceText: 'Please update me on the patrol position.',
                  originalDraftText:
                      'We are checking the latest patrol position now and will send the next verified update shortly.',
                  draftText:
                      'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
                  createdAtUtc: _clientsRouteOccurredAtUtc(45),
                  usedLearnedApprovalStyle: true,
                ),
              ]),
              ...legacyLearnedApprovalRuntimeState(const <String>[
                'Control is checking the latest position now and will share the next confirmed step shortly.',
              ]),
            });
            await pumpAdminRouteApp(
              tester,
              key: const ValueKey('clients-admin-clear-learned-source-app'),
            );
            await openAdminPendingDraftReview(tester);
            break;
          case 'liveOpsClear':
            await saveLegacyLearnedApprovalStyles(const <String>[
              'Control is checking the latest position now and will share the next confirmed step shortly.',
            ]);
            await pumpLiveOperationsSourceApp(
              tester,
              key: const ValueKey('clients-live-ops-clear-learned-source-app'),
            );
            break;
        }

        final clearLearnedStyleButton = find.widgetWithText(
          OutlinedButton,
          'Clear Learned Style',
        );
        await tester.ensureVisible(clearLearnedStyleButton.first);
        await tester.tap(clearLearnedStyleButton.first);
        await tester.pumpAndSettle();

        await pumpClientControlSourceApp(tester, key: scenario.appKey);

        for (final text in scenario.expectedTexts) {
          expect(find.text(text), findsOneWidget);
        }
        for (final text in scenario.absentTexts) {
          expect(find.text(text), findsNothing);
        }
      }

      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scenarios =
          <
            ({
              ValueKey<String> restartKey,
              ValueKey<String> sourceKey,
              String clientId,
              List<DispatchEvent> initialStoreEventsOverride,
              bool isolateDefaultLane,
              String approvedDraftText,
              String siteId,
            })
          >[
            (
              sourceKey: const ValueKey('clients-offscope-learn-review-app'),
              restartKey: const ValueKey(
                'clients-offscope-learn-review-restart-app',
              ),
              clientId: 'CLIENT-DEMO',
              siteId: 'WTF-MAIN',
              initialStoreEventsOverride: <DispatchEvent>[
                _waterfallDispatchDecision(
                  dispatchId: 'DISP-WTF-LEARN-1',
                  occurredAt: _clientsOffScopeOccurredAtUtc(41),
                ),
              ],
              isolateDefaultLane: true,
              approvedDraftText:
                  'Control is checking the Waterfall dispatch response for Resident Feed now and will share the next confirmed step shortly.',
            ),
            (
              sourceKey: const ValueKey('clients-learn-review-app'),
              restartKey: const ValueKey('clients-learn-review-restart-app'),
              clientId: 'CLIENT-DEMO',
              siteId: 'SITE-DEMO',
              initialStoreEventsOverride: const <DispatchEvent>[],
              isolateDefaultLane: false,
              approvedDraftText:
                  'Control is checking the dispatch response for Resident Feed now and will share the next confirmed step shortly.',
            ),
          ];

      for (final scenario in scenarios) {
        await pumpClientControlSourceApp(
          tester,
          key: scenario.sourceKey,
          clientId: scenario.clientId,
          siteId: scenario.siteId,
          initialStoreEventsOverride: scenario.initialStoreEventsOverride,
        );

        final reviewButton = find.textContaining(
          'Review dispatch draft for Resident Feed',
        );
        await tester.ensureVisible(reviewButton.first);
        await tester.tap(reviewButton.first);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).first,
          scenario.approvedDraftText,
        );
        await tester.pumpAndSettle();

        final sendReviewedDraftButton = find.widgetWithText(
          FilledButton,
          'Log Dispatch Review for Resident Feed',
        );
        await tester.ensureVisible(sendReviewedDraftButton);
        await tester.tap(sendReviewedDraftButton);
        await tester.pumpAndSettle();

        await pumpClientControlSourceApp(
          tester,
          key: scenario.restartKey,
          clientId: scenario.clientId,
          siteId: scenario.siteId,
        );

        await openClientControlAnchor(tester, 'Learned approval style');

        if (scenario.siteId == 'WTF-MAIN') {
          expect(
            find.text('Security Desk Console — CLIENT-DEMO / WTF-MAIN'),
            findsOneWidget,
          );
        }
        expect(find.text('ONYX mode: Learned approvals'), findsOneWidget);
        expect(find.text('Learned approvals (1)'), findsOneWidget);
        expect(find.textContaining(scenario.approvedDraftText), findsWidgets);

        if (scenario.isolateDefaultLane) {
          await pumpClientControlSourceApp(
            tester,
            key: const ValueKey('clients-default-learn-review-isolation'),
          );

          expect(
            find.text('Security Desk Console — CLIENT-DEMO / SITE-DEMO'),
            findsOneWidget,
          );
          expect(find.text('Learned approval style'), findsNothing);
          expect(find.textContaining(scenario.approvedDraftText), findsNothing);
        }
      }
    },
  );

  testWidgets(
    'onyx app keeps reviewed draft learning live when telegram admin runtime persistence fails',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final previousStore = SharedPreferencesStorePlatform.instance;
      final failingStore = _FailingTelegramAdminRuntimeStore();
      SharedPreferencesStorePlatform.instance = failingStore;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previousStore;
      });
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('clients-learn-review-runtime-failure-app'),
        clientId: 'CLIENT-DEMO',
        siteId: 'SITE-DEMO',
      );

      final reviewButton = find.textContaining(
        'Review dispatch draft for Resident Feed',
      );
      await tester.ensureVisible(reviewButton.first);
      await tester.tap(reviewButton.first);
      await tester.pumpAndSettle();

      const approvedDraftText =
          'Control is checking the dispatch response for Resident Feed now and will share the next confirmed step shortly.';
      await tester.enterText(find.byType(TextField).first, approvedDraftText);
      await tester.pumpAndSettle();

      final sendReviewedDraftButton = find.widgetWithText(
        FilledButton,
        'Log Dispatch Review for Resident Feed',
      );
      await tester.ensureVisible(sendReviewedDraftButton);
      await tester.tap(sendReviewedDraftButton);
      await tester.pumpAndSettle();

      await openClientControlAnchor(tester, 'Learned approval style');
      expect(find.text('ONYX mode: Learned approvals'), findsOneWidget);
      expect(find.text('Learned approvals (1)'), findsOneWidget);
      expect(find.textContaining(approvedDraftText), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app treats recent DVR recovery alerts as limited visibility instead of offline for client site-status asks',
    (tester) async {
      final nowUtc = _clientsStatusNowUtc();
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('clients-direct-recorder-recovery-status'),
        prompt: "what's happening on site?",
        updateId: 90421,
        sentAtUtc: nowUtc,
        dvrScopeConfigsOverride: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri.parse(
              'http://192.168.0.117/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'digest',
            username: 'operator',
            password: 'secret',
            bearerToken: '',
          ),
        ],
        initialStoreEventsOverride: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'recovery-clear-1',
            sequence: 1,
            version: 1,
            occurredAt: nowUtc.subtract(
              const Duration(minutes: 2, seconds: 30),
            ),
            intelligenceId: 'intel-recovery-clear-1',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'ext-recovery-clear-1',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            cameraId: 'channel-0',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_LOSS_CLEARED',
            summary: 'camera:channel-0 | videoloss alarm inactive',
            riskScore: 8,
            canonicalHash: 'hash-recovery-clear-1',
          ),
        ],
      );

      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n');

      expect(
        sentTranscript,
        contains('Remote monitoring is unavailable at Site Demo right now.'),
      );
      expect(sentTranscript, contains('manual follow-up'));
    },
  );

  testWidgets(
    'onyx app routes check-site-status asks through the packetized client status lane',
    (tester) async {
      final nowUtc = _clientsStatusNowUtc();
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('clients-direct-recorder-check-site-status'),
        prompt: 'check site status',
        updateId: 90421,
        sentAtUtc: nowUtc,
        dvrScopeConfigsOverride: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri.parse(
              'http://192.168.0.117/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'digest',
            username: 'operator',
            password: 'secret',
            bearerToken: '',
          ),
        ],
        initialStoreEventsOverride: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'recovery-clear-check-site-status',
            sequence: 1,
            version: 1,
            occurredAt: nowUtc.subtract(const Duration(minutes: 2)),
            intelligenceId: 'intel-recovery-clear-check-site-status',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'ext-recovery-clear-check-site-status',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            cameraId: 'channel-0',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_LOSS_CLEARED',
            summary: 'camera:channel-0 | videoloss alarm inactive',
            riskScore: 8,
            canonicalHash: 'hash-recovery-clear-check-site-status',
          ),
        ],
      );

      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n');

      expect(
        sentTranscript,
        contains('Remote monitoring is unavailable at Site Demo right now.'),
      );
      expect(
        sentTranscript,
        isNot(
          contains(
            'The latest logged signal was community reports suspicious vehicle',
          ),
        ),
      );
    },
  );

  testWidgets(
    'onyx app camera-check does not fabricate a latest camera picture when only limited visibility is available',
    (tester) async {
      final nowUtc = _clientsStatusNowUtc();
      final bridge = await pumpClientTelegramPromptThroughRoute(
        tester,
        appKey: const ValueKey('clients-direct-recorder-recovery-camera-check'),
        prompt: 'check cameras',
        updateId: 90422,
        sentAtUtc: nowUtc,
        dvrScopeConfigsOverride: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri.parse(
              'http://192.168.0.117/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'digest',
            username: 'operator',
            password: 'secret',
            bearerToken: '',
          ),
        ],
        initialStoreEventsOverride: <DispatchEvent>[
          IntelligenceReceived(
            eventId: 'recovery-clear-2',
            sequence: 1,
            version: 1,
            occurredAt: nowUtc.subtract(
              const Duration(minutes: 2, seconds: 30),
            ),
            intelligenceId: 'intel-recovery-clear-2',
            provider: 'hikvision_dvr_monitor_only',
            sourceType: 'dvr',
            externalId: 'ext-recovery-clear-2',
            clientId: 'CLIENT-DEMO',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-DEMO',
            cameraId: 'channel-0',
            headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_LOSS_CLEARED',
            summary: 'camera:channel-0 | videoloss alarm inactive',
            riskScore: 8,
            canonicalHash: 'hash-recovery-clear-2',
          ),
        ],
      );

      final sentTranscript = bridge.sentMessages
          .map((message) => message.text)
          .join('\n');

      expect(
        sentTranscript,
        contains(
          'Live camera visibility at Site Demo is unavailable right now.',
        ),
      );
      expect(
        sentTranscript,
        isNot(contains('The latest camera picture for Site Demo')),
      );
    },
  );
}

DecisionCreated _waterfallDispatchDecision({
  required String dispatchId,
  required DateTime occurredAt,
}) {
  return DecisionCreated(
    eventId: 'evt-$dispatchId',
    sequence: 1,
    version: 1,
    occurredAt: occurredAt,
    dispatchId: dispatchId,
    clientId: 'CLIENT-DEMO',
    regionId: 'REGION-GAUTENG',
    siteId: 'WTF-MAIN',
  );
}
