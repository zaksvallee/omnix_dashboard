import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/client_camera_health_fact_packet_service.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/application/telegram_ai_assistant_service.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/incident_closed.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';
import 'package:omnix_dashboard/ui/client_intelligence_reports_page.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';
import 'package:omnix_dashboard/ui/governance_page.dart';
import 'package:omnix_dashboard/ui/live_operations_page.dart';
import 'package:omnix_dashboard/ui/tactical_page.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';

import 'support/admin_route_test_harness.dart';
import 'support/admin_route_state_harness.dart';
import 'support/telegram_route_assertions.dart';

DateTime _adminRouteNowUtc() => DateTime.now().toUtc();

DateTime _freshCameraBridgeCheckedAtUtc() =>
    _adminRouteNowUtc().subtract(const Duration(minutes: 5));

DateTime _staleCameraBridgeCheckedAtUtc() =>
    _adminRouteNowUtc().subtract(const Duration(hours: 2));

DateTime _adminDraftCreatedAtUtc(int minute) =>
    DateTime.utc(2026, 3, 18, 12, minute);

DateTime _adminOffScopeOccurredAtUtc(int minute) =>
    DateTime.utc(2026, 3, 19, 6, minute);

class _SuccessfulTelegramBridgeStub implements TelegramBridgeService {
  const _SuccessfulTelegramBridgeStub();

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
    return TelegramBridgeSendResult(
      sent: messages,
      failed: const [],
      telegramMessageIdsByMessageKey: {
        for (final message in messages) message.messageKey: 9001,
      },
    );
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

class _PollingTelegramBridgeStub implements TelegramBridgeService {
  _PollingTelegramBridgeStub(this.updates);

  final List<TelegramBridgeInboundMessage> updates;
  final List<TelegramBridgeMessage> sentMessages = <TelegramBridgeMessage>[];
  final List<int?> requestedOffsets = <int?>[];

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
    requestedOffsets.add(offset);
    return updates
        .where((update) => offset == null || update.updateId >= offset)
        .take(limit)
        .toList(growable: false);
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

class _ThrowingAdminTelegramAiAssistantStub
    implements TelegramAiAssistantService {
  const _ThrowingAdminTelegramAiAssistantStub();

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
  }) async {
    throw StateError('admin ai draft failed');
  }
}

class _FlakyAdminTelegramAiAssistantStub
    implements TelegramAiAssistantService {
  _FlakyAdminTelegramAiAssistantStub();

  int failuresBeforeSuccess = 1;

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
  }) async {
    if (audience == TelegramAiAudience.admin &&
        messageText.trim().toLowerCase() == 'hello onyx' &&
        failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw StateError('transient admin ai failure');
    }
    return const TelegramAiDraftReply(
      text: 'Recovered AI reply.',
      providerLabel: 'test-ai',
    );
  }
}

class _RouteFakeCameraBridgeHealthService
    implements OnyxAgentCameraBridgeHealthService {
  const _RouteFakeCameraBridgeHealthService();

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCameraBridgeHealthSnapshot> probe(Uri endpoint) async {
    return OnyxAgentCameraBridgeHealthSnapshot(
      requestedEndpoint: endpoint,
      healthEndpoint: endpoint.replace(path: '/health'),
      reportedEndpoint: endpoint,
      reachable: true,
      running: true,
      statusCode: 200,
      statusLabel: 'Healthy',
      detail:
          'GET /health succeeded and the bridge reported packet ingress ready.',
      executePath: '/execute',
      checkedAtUtc: _freshCameraBridgeCheckedAtUtc(),
      operatorId: 'OPERATOR-01',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seedScopedAdminTelegramRuntime() async {
    await saveTelegramAdminRuntimeState({
      'allowed_user_ids_override': <int>[77],
      'target_client_override': 'CLIENT-MS-VALLEE',
      'target_site_override': 'SITE-MS-VALLEE-RESIDENCE',
    });
  }

  Future<void> openCameraBridgeFromApprovedTelegramOnboarding(
    WidgetTester tester, {
    required Key appKey,
    TelegramBridgeService? telegramBridgeServiceOverride,
    OnyxAgentCameraBridgeStatus? onyxAgentCameraBridgeStatusOverride,
    OnyxAgentCameraBridgeHealthService?
    onyxAgentCameraBridgeHealthServiceOverride,
    int createUpdateId = 44107,
    int approveUpdateId = 44108,
  }) async {
    await prepareAdminRouteTest(tester);
    await seedScopedAdminTelegramRuntime();

    final now = DateTime.now().toUtc();
    await pumpAdminRouteApp(
      tester,
      key: appKey,
      initialAdminTab: AdministrationPageTab.system,
      telegramBridgeServiceOverride:
          telegramBridgeServiceOverride ?? _RecordingTelegramBridgeStub(),
      onyxAgentCameraBridgeStatusOverride: onyxAgentCameraBridgeStatusOverride,
      onyxAgentCameraBridgeHealthServiceOverride:
          onyxAgentCameraBridgeHealthServiceOverride,
      telegramAdminChatIdOverride: 'test-admin-chat',
      initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
        TelegramBridgeInboundMessage(
          updateId: createUpdateId,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text:
              'Create new client Akhalawayas Robertsham, Robertsham Estate, cameras 32, vendor Hikvision, contact John Smith',
          sentAtUtc: now,
        ),
        TelegramBridgeInboundMessage(
          updateId: approveUpdateId,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: 'approve this client',
          sentAtUtc: now.add(const Duration(seconds: 4)),
        ),
      ],
    );

    final openSiteButton = find.byKey(
      const ValueKey('admin-system-telegram-onboarding-open-site'),
    );
    await tester.ensureVisible(openSiteButton);
    await tester.tap(openSiteButton);
    await tester.pumpAndSettle();

    final openCameraBridgeButton = find.byKey(
      const ValueKey('site-onboarding-telegram-seed-open-camera-bridge'),
    );
    expect(openCameraBridgeButton, findsOneWidget);
    await tester.ensureVisible(openCameraBridgeButton);
    await tester.tap(openCameraBridgeButton);
    await tester.pumpAndSettle();
  }

  Future<void> saveApprovedTelegramBridgeRuntimeState({
    Map<String, Object?> progress = const <String, Object?>{},
  }) async {
    await saveTelegramAdminRuntimeState({
      'approved_onboarding_prefill': <String, Object?>{
        'client_id': 'CLIENT-AKHALAWAYAS-ROBERTSHAM',
        'client_name': 'Akhalawayas Robertsham',
        'site_id': 'SITE-ROBERTSHAM-ESTATE',
        'site_name': 'Robertsham Estate',
        'camera_count': 32,
        'vendor': 'Hikvision',
        'contact_name': 'John Smith',
        'wants_telegram_binding': true,
      },
      'approved_onboarding_bridge_runbook_progress': <String, Object?>{
        'client_id': 'CLIENT-AKHALAWAYAS-ROBERTSHAM',
        'site_id': 'SITE-ROBERTSHAM-ESTATE',
        ...progress,
      },
    });
  }

  Future<void> restoreApprovedTelegramOnboardingAfterRestart(
    WidgetTester tester, {
    required Key firstAppKey,
    required Key secondAppKey,
    int createUpdateId = 44101,
    int approveUpdateId = 44102,
  }) async {
    await prepareAdminRouteTest(tester);
    await seedScopedAdminTelegramRuntime();

    final firstBridge = _RecordingTelegramBridgeStub();
    final secondBridge = _RecordingTelegramBridgeStub();
    final now = DateTime.now().toUtc();

    await pumpAdminRouteApp(
      tester,
      key: firstAppKey,
      initialAdminTab: AdministrationPageTab.system,
      telegramBridgeServiceOverride: firstBridge,
      telegramAdminChatIdOverride: 'test-admin-chat',
      initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
        TelegramBridgeInboundMessage(
          updateId: createUpdateId,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text:
              'Create new client Akhalawayas Robertsham, Robertsham Estate, cameras 32, vendor Hikvision, contact John Smith',
          sentAtUtc: now,
        ),
        TelegramBridgeInboundMessage(
          updateId: approveUpdateId,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: 'approve this client',
          sentAtUtc: now.add(const Duration(seconds: 4)),
        ),
      ],
    );

    expect(firstBridge.sentMessages.length, greaterThanOrEqualTo(2));

    await pumpAdminRouteApp(
      tester,
      key: secondAppKey,
      initialAdminTab: AdministrationPageTab.system,
      telegramBridgeServiceOverride: secondBridge,
      telegramAdminChatIdOverride: 'test-admin-chat',
    );
  }

  Future<String> restorePendingAdminOnboardingAfterRestart(
    WidgetTester tester, {
    required Key firstAppKey,
    required Key secondAppKey,
    required String firstPrompt,
    required String secondPrompt,
    int firstUpdateId = 44131,
    int secondUpdateId = 44132,
  }) async {
    await prepareAdminRouteTest(tester);
    await seedScopedAdminTelegramRuntime();

    final firstBridge = _RecordingTelegramBridgeStub();
    final secondBridge = _RecordingTelegramBridgeStub();
    final now = DateTime.now().toUtc();

    await pumpAdminRouteApp(
      tester,
      key: firstAppKey,
      initialAdminTab: AdministrationPageTab.system,
      telegramBridgeServiceOverride: firstBridge,
      telegramAdminChatIdOverride: 'test-admin-chat',
      initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
        TelegramBridgeInboundMessage(
          updateId: firstUpdateId,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: firstPrompt,
          sentAtUtc: now,
        ),
      ],
    );

    expect(firstBridge.sentMessages, isNotEmpty);

    await pumpAdminRouteApp(
      tester,
      key: secondAppKey,
      initialAdminTab: AdministrationPageTab.system,
      telegramBridgeServiceOverride: secondBridge,
      telegramAdminChatIdOverride: 'test-admin-chat',
      initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
        TelegramBridgeInboundMessage(
          updateId: secondUpdateId,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: secondPrompt,
          sentAtUtc: now.add(const Duration(seconds: 5)),
        ),
      ],
    );

    expect(secondBridge.sentMessages, isNotEmpty);
    return secondBridge.sentMessages
        .map((message) => message.text)
        .join('\n---\n');
  }

  Future<_RecordingTelegramBridgeStub> pumpApprovedAdminTelegramOnboardingRoute(
    WidgetTester tester, {
    required Key appKey,
    required AdministrationPageTab initialAdminTab,
    int createUpdateId = 44109,
    int approveUpdateId = 44110,
  }) async {
    await prepareAdminRouteTest(tester);
    await seedScopedAdminTelegramRuntime();

    final bridge = _RecordingTelegramBridgeStub();
    final now = DateTime.now().toUtc();

    await pumpAdminRouteApp(
      tester,
      key: appKey,
      initialAdminTab: initialAdminTab,
      telegramBridgeServiceOverride: bridge,
      telegramAdminChatIdOverride: 'test-admin-chat',
      initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
        TelegramBridgeInboundMessage(
          updateId: createUpdateId,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text:
              'Create new client Akhalawayas Robertsham, Robertsham Estate, cameras 32, vendor Hikvision, contact John Smith',
          sentAtUtc: now,
        ),
        TelegramBridgeInboundMessage(
          updateId: approveUpdateId,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: 'approve this client',
          sentAtUtc: now.add(const Duration(seconds: 4)),
        ),
      ],
    );

    expect(bridge.sentMessages.length, greaterThanOrEqualTo(2));
    return bridge;
  }

  Future<String> sendAdminTelegramPromptThroughRoute(
    WidgetTester tester, {
    required Key appKey,
    required String prompt,
    required int updateId,
    String chatType = 'group',
    DateTime? sentAtUtc,
    List<DispatchEvent> initialStoreEventsOverride = const <DispatchEvent>[],
  }) async {
    await prepareAdminRouteTest(tester);
    await seedScopedAdminTelegramRuntime();

    final bridge = _RecordingTelegramBridgeStub();
    final now = DateTime.now().toUtc();

    await pumpAdminRouteApp(
      tester,
      key: appKey,
      initialAdminTab: AdministrationPageTab.system,
      telegramBridgeServiceOverride: bridge,
      telegramAdminChatIdOverride: 'test-admin-chat',
      initialStoreEventsOverride: initialStoreEventsOverride,
      initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
        TelegramBridgeInboundMessage(
          updateId: updateId,
          chatId: 'test-admin-chat',
          chatType: chatType,
          fromUserId: 77,
          text: prompt,
          sentAtUtc: sentAtUtc ?? now,
        ),
      ],
    );

    expect(bridge.sentMessages, isNotEmpty, reason: prompt);
    return telegramTranscriptFromMessages(bridge.sentMessages);
  }

  Future<String> sendAdminTelegramConversationThroughRoute(
    WidgetTester tester, {
    required Key appKey,
    required List<String> prompts,
    required int firstUpdateId,
    List<DispatchEvent> initialStoreEventsOverride = const <DispatchEvent>[],
  }) async {
    await prepareAdminRouteTest(tester);
    await seedScopedAdminTelegramRuntime();

    final bridge = _RecordingTelegramBridgeStub();
    final now = DateTime.now().toUtc();

    await pumpAdminRouteApp(
      tester,
      key: appKey,
      initialAdminTab: AdministrationPageTab.system,
      telegramBridgeServiceOverride: bridge,
      telegramAdminChatIdOverride: 'test-admin-chat',
      initialStoreEventsOverride: initialStoreEventsOverride,
      initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
        for (var index = 0; index < prompts.length; index++)
          TelegramBridgeInboundMessage(
            updateId: firstUpdateId + index,
            chatId: 'test-admin-chat',
            chatType: 'group',
            fromUserId: 77,
            text: prompts[index],
            sentAtUtc: now.add(Duration(seconds: index * 4)),
          ),
      ],
    );

    expect(bridge.sentMessages.length, greaterThanOrEqualTo(prompts.length));
    return telegramTranscriptFromMessages(bridge.sentMessages);
  }

  testWidgets(
    'onyx app continues later admin telegram updates when an earlier AI draft fails in the same batch',
    (tester) async {
      await prepareAdminRouteTest(tester);
      await seedScopedAdminTelegramRuntime();

      final bridge = _RecordingTelegramBridgeStub();
      final now = DateTime.now().toUtc();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-telegram-ai-failure-batch-continues'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
          telegramBridgeServiceOverride: bridge,
          telegramAdminChatIdOverride: 'test-admin-chat',
          telegramAiAssistantEnabledOverride: true,
          telegramAiAssistantServiceOverride:
              const _ThrowingAdminTelegramAiAssistantStub(),
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 99101,
              chatId: 'test-admin-chat',
              chatType: 'group',
              fromUserId: 77,
              text: 'hello onyx',
              sentAtUtc: now,
            ),
            TelegramBridgeInboundMessage(
              updateId: 99102,
              chatId: 'test-admin-chat',
              chatType: 'group',
              fromUserId: 77,
              text: 'brief ops',
              sentAtUtc: now.add(const Duration(seconds: 4)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final transcript = telegramTranscriptFromMessages(bridge.sentMessages);

      expect(transcript, contains('ONYX BRIEF'));
      expect(transcript, contains('Scope In Focus'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onyx app processes pending admin telegram backlog on startup instead of skipping to the latest update',
    (tester) async {
      await prepareAdminRouteTest(tester);
      await saveTelegramAdminRuntimeState({
        'allowed_user_ids_override': <int>[77],
        'target_client_override': 'CLIENT-MS-VALLEE',
        'target_site_override': 'SITE-MS-VALLEE-RESIDENCE',
        'poll_interval_override_seconds': 1,
      });
      final bridge = _PollingTelegramBridgeStub(<TelegramBridgeInboundMessage>[
        TelegramBridgeInboundMessage(
          updateId: 601,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: '/whoami',
          sentAtUtc: _adminRouteNowUtc(),
        ),
        TelegramBridgeInboundMessage(
          updateId: 602,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: '/brief',
          sentAtUtc: _adminRouteNowUtc().add(const Duration(seconds: 4)),
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-backlog-startup-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          telegramBridgeServiceOverride: bridge,
          telegramAdminChatIdOverride: 'test-admin-chat',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      final transcript = telegramTranscriptFromMessages(bridge.sentMessages);
      expect(bridge.requestedOffsets.first, isNull);
      expect(transcript, contains('ONYX WHOAMI'));
      expect(transcript, contains('ONYX BRIEF'));
    },
  );

  testWidgets(
    'onyx app retries failed admin telegram updates without duplicating later handled replies',
    (tester) async {
      await prepareAdminRouteTest(tester);
      await saveTelegramAdminRuntimeState({
        'allowed_user_ids_override': <int>[77],
        'target_client_override': 'CLIENT-MS-VALLEE',
        'target_site_override': 'SITE-MS-VALLEE-RESIDENCE',
        'poll_interval_override_seconds': 1,
      });
      final bridge = _PollingTelegramBridgeStub(<TelegramBridgeInboundMessage>[
        TelegramBridgeInboundMessage(
          updateId: 701,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: 'hello onyx',
          sentAtUtc: _adminRouteNowUtc(),
        ),
        TelegramBridgeInboundMessage(
          updateId: 702,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: '/brief',
          sentAtUtc: _adminRouteNowUtc().add(const Duration(seconds: 4)),
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-retryable-update-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          telegramBridgeServiceOverride: bridge,
          telegramAdminChatIdOverride: 'test-admin-chat',
          telegramAiAssistantEnabledOverride: true,
          telegramAiAssistantServiceOverride: _FlakyAdminTelegramAiAssistantStub(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      final transcript = telegramTranscriptFromMessages(bridge.sentMessages);
      expect(
        RegExp('ONYX BRIEF').allMatches(transcript).length,
        1,
      );
      expect(
        RegExp('Recovered AI reply\\.').allMatches(transcript).length,
        1,
      );
      expect(bridge.requestedOffsets, contains(701));
    },
  );

  testWidgets(
    'onyx app leaves unhandled admin telegram updates retryable without duplicating later replies',
    (tester) async {
      await prepareAdminRouteTest(tester);
      await saveTelegramAdminRuntimeState({
        'allowed_user_ids_override': <int>[77],
        'target_client_override': 'CLIENT-MS-VALLEE',
        'target_site_override': 'SITE-MS-VALLEE-RESIDENCE',
        'poll_interval_override_seconds': 1,
      });
      final bridge = _PollingTelegramBridgeStub(<TelegramBridgeInboundMessage>[
        TelegramBridgeInboundMessage(
          updateId: 711,
          chatId: 'other-chat',
          chatType: 'group',
          fromUserId: 77,
          text: 'hello from another room',
          sentAtUtc: _adminRouteNowUtc(),
        ),
        TelegramBridgeInboundMessage(
          updateId: 712,
          chatId: 'test-admin-chat',
          chatType: 'group',
          fromUserId: 77,
          text: '/brief',
          sentAtUtc: _adminRouteNowUtc().add(const Duration(seconds: 4)),
        ),
      ]);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-unhandled-update-retry-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          telegramBridgeServiceOverride: bridge,
          telegramAdminChatIdOverride: 'test-admin-chat',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      final transcript = telegramTranscriptFromMessages(bridge.sentMessages);
      expect(RegExp('ONYX BRIEF').allMatches(transcript).length, 1);
      expect(bridge.requestedOffsets, contains(711));
    },
  );

  testWidgets(
    'onyx app answers admin free-text with deterministic fallback when AI is disabled',
    (tester) async {
      await prepareAdminRouteTest(tester);
      await seedScopedAdminTelegramRuntime();
      final bridge = _RecordingTelegramBridgeStub();

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-ai-disabled-free-text-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          telegramBridgeServiceOverride: bridge,
          telegramAdminChatIdOverride: 'test-admin-chat',
          telegramAiAssistantEnabledOverride: false,
          initialTelegramInboundUpdatesOverride: <TelegramBridgeInboundMessage>[
            TelegramBridgeInboundMessage(
              updateId: 801,
              chatId: 'test-admin-chat',
              chatType: 'group',
              fromUserId: 77,
              text: 'hello onyx',
              sentAtUtc: _adminRouteNowUtc(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final transcript = telegramTranscriptFromMessages(bridge.sentMessages);
      expect(transcript, contains('ONYX ADMIN'));
      expect(transcript, contains('I could not route that request yet.'));
    },
  );

  testWidgets(
    'onyx app keeps admin onboarding prompts, state, and incident reads deterministic across follow-ups and restart',
    (tester) async {
      final initialPromptCases =
          <({String prompt, int updateId, List<String> expected, List<String> forbidden})>[
            (
              prompt: 'Client onboarding. Akhalawayas Robertsham',
              updateId: 4406,
              expected: const <String>[
                'ONYX ONBOARDING INTAKE',
                'Client: Akhalawayas Robertsham',
                'Nothing has been executed yet.',
              ],
              forbidden: const <String>[
                'I can respond directly without slash commands.',
              ],
            ),
            (
              prompt: 'client onboarding',
              updateId: 4407,
              expected: const <String>[
                'ONYX ONBOARDING INTAKE',
                'Send: Add new client: <name>, <site>, <camera count>, <vendor>, <contact>.',
              ],
              forbidden: const <String>[
                'I can respond directly without slash commands.',
              ],
            ),
            (
              prompt: 'start onboarding for Akhalawayas Robertsham',
              updateId: 44071,
              expected: const <String>[
                'ONYX ONBOARDING INTAKE',
                'Client: Akhalawayas Robertsham',
                'Nothing has been executed yet.',
              ],
              forbidden: const <String>[],
            ),
            (
              prompt: 'Onboard Akhalawayas Robertsham',
              updateId: 44072,
              expected: const <String>[
                'ONYX ONBOARDING INTAKE',
                'Client: Akhalawayas Robertsham',
                'Nothing has been executed yet.',
              ],
              forbidden: const <String>[],
            ),
            (
              prompt: 'Set up new client Akhalawayas Robertsham',
              updateId: 44074,
              expected: const <String>[
                'ONYX ONBOARDING INTAKE',
                'Client: Akhalawayas Robertsham',
                'Nothing has been executed yet.',
              ],
              forbidden: const <String>[],
            ),
            (
              prompt: 'Create new client Akhalawayas Robertsham',
              updateId: 44073,
              expected: const <String>[
                'ONYX ONBOARDING INTAKE',
                'Client: Akhalawayas Robertsham',
                'Intake status: waiting for site',
                'Next detail I need: site',
                'Reply with: site <property name>',
                "After that I'll ask for: camera count, vendor, contact",
                'Nothing has been executed yet.',
              ],
              forbidden: const <String>[],
            ),
            (
              prompt:
                  'Add new client: Akhalawayas Robertsham, Robertsham Estate, 32 cameras, Hikvision, contact John, https://t.me/+abc123',
              updateId: 4408,
              expected: const <String>[
                'ONYX ONBOARDING INTAKE',
                'Client: Akhalawayas Robertsham',
                'Site: Robertsham Estate',
                'Cameras: 32',
                'Vendor: Hikvision',
                'Contact: John',
                'Telegram: invite link received (1)',
                '/linkchat CLIENT-AKHALAWAYAS-ROBERTSHAM SITE-ROBERTSHAM-ESTATE',
                'Nothing has been executed yet.',
              ],
              forbidden: const <String>[],
            ),
          ];

      for (var index = 0; index < initialPromptCases.length; index += 1) {
        final scenario = initialPromptCases[index];
        final sentTranscript = await sendAdminTelegramPromptThroughRoute(
          tester,
          appKey: ValueKey('admin-telegram-onboarding-alias-app-$index'),
          prompt: scenario.prompt,
          updateId: scenario.updateId,
        );
        for (final text in scenario.expected) {
          expect(sentTranscript, contains(text), reason: scenario.prompt);
        }
        for (final text in scenario.forbidden) {
          expect(sentTranscript, isNot(contains(text)), reason: scenario.prompt);
        }
      }

      final progressionCases =
          <({String prompt, int updateId, List<String> expected, List<String> forbidden})>[
            (
              prompt: 'Create new client Akhalawayas Robertsham, Robertsham Estate',
              updateId: 44075,
              expected: const <String>[
                'Client: Akhalawayas Robertsham',
                'Site: Robertsham Estate',
                'Intake status: waiting for camera count',
                'Next detail I need: camera count',
                'Reply with: cameras <count>',
                "After that I'll ask for: vendor, contact",
              ],
              forbidden: const <String>[],
            ),
            (
              prompt:
                  'Create new client Akhalawayas Robertsham, Robertsham Estate, cameras 32',
              updateId: 44076,
              expected: const <String>[
                'Client: Akhalawayas Robertsham',
                'Site: Robertsham Estate',
                'Cameras: 32',
                'Intake status: waiting for vendor',
                'Next detail I need: vendor',
                'Reply with: vendor <brand>',
                "After that I'll ask for: contact",
              ],
              forbidden: const <String>[],
            ),
            (
              prompt:
                  'Create new client Akhalawayas Robertsham, Robertsham Estate, cameras 32, vendor Hikvision',
              updateId: 44077,
              expected: const <String>[
                'Vendor: Hikvision',
                'Intake status: waiting for contact',
                'Next detail I need: contact',
                'Reply with: contact <name>',
              ],
              forbidden: const <String>[],
            ),
            (
              prompt:
                  'Create new client Akhalawayas Robertsham, https://t.me/+testinvite',
              updateId: 44078,
              expected: const <String>[
                'Telegram: invite link received (1)',
                'Intake status: waiting for site',
                'Next detail I need: site',
                'Telegram note: invite link saved for the bind step.',
                'After we finish the intake, add the ONYX bot to that group and run:',
                '/linkchat CLIENT-AKHALAWAYAS-ROBERTSHAM SITE-AKHALAWAYAS-ROBERTSHAM',
              ],
              forbidden: const <String>[],
            ),
            (
              prompt:
                  'Create new client Akhalawayas Robertsham, Robertsham Estate, cameras 32, Hikvision, John Smith',
              updateId: 44079,
              expected: const <String>[
                'Contact: John Smith',
                'Intake status: ready for approval',
                'Ready for approval and desk setup.',
              ],
              forbidden: const <String>[],
            ),
            (
              prompt:
                  'Create new client Akhalawayas Robertsham, Robertsham Estate, cameras 32, vendor Hikvision, contact John Smith, https://t.me/+testinvite',
              updateId: 44080,
              expected: const <String>[
                'Telegram: invite link received (1)',
                'Intake status: ready for approval',
                'Telegram next step:',
                'Ready for approval, then Telegram bind setup.',
                '/linkchat CLIENT-AKHALAWAYAS-ROBERTSHAM SITE-ROBERTSHAM-ESTATE',
              ],
              forbidden: const <String>[],
            ),
          ];

      for (var index = 0; index < progressionCases.length; index += 1) {
        final scenario = progressionCases[index];
        final sentTranscript = await sendAdminTelegramPromptThroughRoute(
          tester,
          appKey: ValueKey('admin-telegram-onboarding-progression-app-$index'),
          prompt: scenario.prompt,
          updateId: scenario.updateId,
        );
        for (final text in scenario.expected) {
          expect(sentTranscript, contains(text), reason: scenario.prompt);
        }
        for (final text in scenario.forbidden) {
          expect(sentTranscript, isNot(contains(text)), reason: scenario.prompt);
        }
      }

      var sentTranscript = await sendAdminTelegramConversationThroughRoute(
        tester,
        appKey: const ValueKey('admin-telegram-onboarding-follow-up-state-app'),
        prompts: const <String>[
          'Create new client Akhalawayas Robertsham',
          'Robertsham Estate',
        ],
        firstUpdateId: 44081,
      );
      expect(sentTranscript, contains('Client: Akhalawayas Robertsham'));
      expect(sentTranscript, contains('Site: Robertsham Estate'));
      expect(
        sentTranscript,
        contains('Intake status: waiting for camera count'),
      );
      expect(sentTranscript, contains('Reply with: cameras <count>'));

      sentTranscript = await sendAdminTelegramConversationThroughRoute(
        tester,
        appKey: const ValueKey(
          'admin-telegram-onboarding-follow-up-invite-app',
        ),
        prompts: const <String>[
          'Create new client Akhalawayas Robertsham, Robertsham Estate, cameras 32, vendor Hikvision, contact John Smith',
          'https://t.me/+testinvite',
        ],
        firstUpdateId: 44083,
      );
      expect(sentTranscript, contains('Telegram: invite link received (1)'));
      expect(sentTranscript, contains('Telegram next step:'));
      expect(
        sentTranscript,
        contains('Ready for approval, then Telegram bind setup.'),
      );

      sentTranscript = await restorePendingAdminOnboardingAfterRestart(
        tester,
        firstAppKey: const ValueKey(
          'admin-telegram-onboarding-restart-first-app',
        ),
        secondAppKey: const ValueKey(
          'admin-telegram-onboarding-restart-second-app',
        ),
        firstPrompt: 'Create new client Akhalawayas Robertsham',
        secondPrompt: 'Robertsham Estate',
        firstUpdateId: 44085,
        secondUpdateId: 44086,
      );
      expect(sentTranscript, contains('Client: Akhalawayas Robertsham'));
      expect(sentTranscript, contains('Site: Robertsham Estate'));
      expect(
        sentTranscript,
        contains('Intake status: waiting for camera count'),
      );

      final continuationCases =
          <({List<String> prompts, int firstUpdateId, List<String> expected, List<String> forbidden})>[
            (
              prompts: const <String>[
                'Create new client Akhalawayas Robertsham',
                'continue setup',
              ],
              firstUpdateId: 44087,
              expected: const <String>[
                'ONYX ONBOARDING PENDING',
                'I still need site before I can continue setup.',
                'Reply with: site <property name>',
                "After that I'll ask for: camera count, vendor, contact",
              ],
              forbidden: const <String>[],
            ),
            (
              prompts: const <String>[
                'Create new client Akhalawayas Robertsham, Robertsham Estate',
                'load client for now.. ill send cameras list later',
              ],
              firstUpdateId: 440871,
              expected: const <String>[
                'ONYX ONBOARDING PENDING',
                'I still need camera count before I can continue setup.',
                'Reply with: cameras <count>',
              ],
              forbidden: const <String>['I could not route that request yet.'],
            ),
          ];

      for (var index = 0; index < continuationCases.length; index += 1) {
        final scenario = continuationCases[index];
        sentTranscript = await sendAdminTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey('admin-telegram-onboarding-continue-matrix-$index'),
          prompts: scenario.prompts,
          firstUpdateId: scenario.firstUpdateId,
        );
        for (final text in scenario.expected) {
          expect(sentTranscript, contains(text), reason: scenario.prompts.last);
        }
        for (final text in scenario.forbidden) {
          expect(
            sentTranscript,
            isNot(contains(text)),
            reason: scenario.prompts.last,
          );
        }
      }

      final now = DateTime.now().toUtc();
      final localNow = now.toLocal();
      final end = DateTime(localNow.year, localNow.month, localNow.day, 6);
      final start = DateTime(
        end.year,
        end.month,
        end.day,
      ).subtract(const Duration(days: 1)).add(const Duration(hours: 18));
      final latestInWindow = localNow.isBefore(end)
          ? localNow.subtract(const Duration(minutes: 1))
          : end.subtract(const Duration(minutes: 5));
      final latestSafe = localNow.subtract(const Duration(minutes: 1));
      final urgentReadCases =
          <
            ({
              List<String> prompts,
              int firstUpdateId,
              String expectedHeading,
              String expectedToken,
              String? unexpectedToken,
              List<String> forbiddenTranscriptSnippets,
              List<String> extraExpected,
              List<DispatchEvent> events,
              bool expectOnboardingIntake,
              bool expectHeadingAfterOnboarding,
            })
          >[
            (
              prompts: const <String>[
                'there is a fire in the building',
                'Do we have police activity tonight?',
              ],
              firstUpdateId: 440521,
              expectedHeading: "Tonight's incidents for MS Vallee Residence:",
              expectedToken: 'DSP-ADMIN-URGENT-TONIGHT',
              unexpectedToken: 'DSP-ADMIN-URGENT-OLD',
              forbiddenTranscriptSnippets: const <String>[],
              extraExpected: const <String>[],
              expectOnboardingIntake: false,
              expectHeadingAfterOnboarding: false,
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'admin-telegram-urgent-mixed-tonight',
                  sequence: 1,
                  version: 1,
                  occurredAt: latestInWindow.toUtc(),
                  dispatchId: 'DSP-ADMIN-URGENT-TONIGHT',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
                DecisionCreated(
                  eventId: 'admin-telegram-urgent-mixed-tonight-old',
                  sequence: 2,
                  version: 1,
                  occurredAt: start.subtract(const Duration(minutes: 12)).toUtc(),
                  dispatchId: 'DSP-ADMIN-URGENT-OLD',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
              ],
            ),
            (
              prompts: const <String>[
                'need police now',
                'Do we have police activity',
              ],
              firstUpdateId: 440531,
              expectedHeading: 'Unresolved incidents in MS Vallee Residence:',
              expectedToken: 'INC-DSP-ADMIN-URGENT-UNRESOLVED',
              unexpectedToken: null,
              forbiddenTranscriptSnippets: const <String>[],
              extraExpected: const <String>[],
              expectOnboardingIntake: false,
              expectHeadingAfterOnboarding: false,
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'admin-telegram-urgent-mixed-unresolved',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 6)),
                  dispatchId: 'DSP-ADMIN-URGENT-UNRESOLVED',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
              ],
            ),
            (
              prompts: const <String>[
                'need police now',
                'Breaches across all sites?',
              ],
              firstUpdateId: 440541,
              expectedHeading: 'Unresolved incidents in CLIENT-MS-VALLEE:',
              expectedToken: 'INC-DSP-ADMIN-ALL-URGENT-1',
              unexpectedToken: null,
              forbiddenTranscriptSnippets: const <String>[
                'INC-DSP-ADMIN-ALL-URGENT-OTHER',
              ],
              extraExpected: const <String>['INC-DSP-ADMIN-ALL-URGENT-2'],
              expectOnboardingIntake: false,
              expectHeadingAfterOnboarding: false,
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'admin-telegram-urgent-all-sites-unresolved-a',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 7)),
                  dispatchId: 'DSP-ADMIN-ALL-URGENT-1',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
                DecisionCreated(
                  eventId: 'admin-telegram-urgent-all-sites-unresolved-b',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 5)),
                  dispatchId: 'DSP-ADMIN-ALL-URGENT-2',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON-ESTATE',
                ),
                DecisionCreated(
                  eventId: 'admin-telegram-urgent-all-sites-unresolved-other',
                  sequence: 3,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 4)),
                  dispatchId: 'DSP-ADMIN-ALL-URGENT-OTHER',
                  clientId: 'CLIENT-AKHALAWAYAS-ROBERTSHAM',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-ROBERTSHAM-ESTATE',
                ),
              ],
            ),
            (
              prompts: const <String>[
                'there is a fire in the building',
                'Top site across all properties this week?',
              ],
              firstUpdateId: 440551,
              expectedHeading:
                  "This week's alert leader: Sandton Estate (2 alerts)",
              expectedToken: 'Ms Vallee Residence • 1 alert',
              unexpectedToken: null,
              forbiddenTranscriptSnippets: const <String>[],
              extraExpected: const <String>[],
              expectOnboardingIntake: false,
              expectHeadingAfterOnboarding: false,
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'admin-telegram-urgent-all-sites-intel-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: latestSafe
                      .subtract(const Duration(minutes: 3))
                      .toUtc(),
                  intelligenceId: 'INT-ADMIN-URGENT-ALL-1',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-admin-urgent-all-1',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON-ESTATE',
                  headline: 'Boundary alert',
                  summary: 'Boundary alert detected.',
                  riskScore: 62,
                  canonicalHash: 'admin-urgent-all-hash-1',
                ),
                IntelligenceReceived(
                  eventId: 'admin-telegram-urgent-all-sites-intel-2',
                  sequence: 2,
                  version: 1,
                  occurredAt: latestSafe
                      .subtract(const Duration(minutes: 2))
                      .toUtc(),
                  intelligenceId: 'INT-ADMIN-URGENT-ALL-2',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-admin-urgent-all-2',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON-ESTATE',
                  headline: 'Gate alert',
                  summary: 'Unexpected person detected.',
                  riskScore: 70,
                  canonicalHash: 'admin-urgent-all-hash-2',
                ),
                IntelligenceReceived(
                  eventId: 'admin-telegram-urgent-all-sites-intel-3',
                  sequence: 3,
                  version: 1,
                  occurredAt: latestSafe
                      .subtract(const Duration(minutes: 1))
                      .toUtc(),
                  intelligenceId: 'INT-ADMIN-URGENT-ALL-3',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-admin-urgent-all-3',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                  headline: 'Driveway alert',
                  summary: 'Vehicle detected near the driveway.',
                  riskScore: 58,
                  canonicalHash: 'admin-urgent-all-hash-3',
                ),
              ],
            ),
          ];
      final cases =
          <
            ({
              List<String> prompts,
              int firstUpdateId,
              String expectedHeading,
              String expectedToken,
              String? unexpectedToken,
              List<String> forbiddenTranscriptSnippets,
              List<String> extraExpected,
              List<DispatchEvent> events,
              bool expectOnboardingIntake,
              bool expectHeadingAfterOnboarding,
            })
          >[
            (
              prompts: const <String>[
                'Create new client Akhalawayas Robertsham',
                'show unresolved incidents in all sites',
              ],
              firstUpdateId: 440872,
              expectedHeading: 'Unresolved incidents in CLIENT-MS-VALLEE:',
              expectedToken: 'DSP-ALL-1',
              unexpectedToken: null,
              forbiddenTranscriptSnippets: const <String>[],
              extraExpected: const <String>['DSP-ALL-2'],
              expectOnboardingIntake: true,
              expectHeadingAfterOnboarding: true,
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'admin-telegram-all-sites-unresolved-a',
                  sequence: 1,
                  version: 1,
                  occurredAt: DateTime.utc(2026, 3, 29, 10, 3),
                  dispatchId: 'DSP-ALL-1',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
                DecisionCreated(
                  eventId: 'admin-telegram-all-sites-unresolved-b',
                  sequence: 2,
                  version: 1,
                  occurredAt: DateTime.utc(2026, 3, 29, 10, 8),
                  dispatchId: 'DSP-ALL-2',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-ROBERTSHAM-ESTATE',
                ),
              ],
            ),
            (
              prompts: const <String>[
                'Which site has most alerts across all sites this week?',
                'Create new client Akhalawayas Robertsham',
              ],
              firstUpdateId: -1,
              expectedHeading: '',
              expectedToken: '',
              unexpectedToken: null,
              forbiddenTranscriptSnippets: const <String>[],
              extraExpected: const <String>[],
              expectOnboardingIntake: true,
              expectHeadingAfterOnboarding: false,
              events: const <DispatchEvent>[],
            ),
          ];

      final weeklyCases = <({String prompt, int firstUpdateId})>[
        (
          prompt: 'Which site has most alerts across all sites this week?',
          firstUpdateId: 440875,
        ),
        (
          prompt: 'Top site across all properties this week?',
          firstUpdateId: 440877,
        ),
      ];

      final expandedCases =
          <({
            List<String> prompts,
            int firstUpdateId,
            String expectedHeading,
            String expectedToken,
            String? unexpectedToken,
            List<String> forbiddenTranscriptSnippets,
            List<String> extraExpected,
            List<DispatchEvent> events,
            bool expectOnboardingIntake,
            bool expectHeadingAfterOnboarding,
          })>[
            ...urgentReadCases,
            cases.first,
            for (final scenario in weeklyCases)
              (
                prompts: <String>[
                  'Create new client Akhalawayas Robertsham',
                  scenario.prompt,
                ],
                firstUpdateId: scenario.firstUpdateId,
                expectedHeading:
                    "This week's alert leader: Sandton Estate (2 alerts)",
                expectedToken: 'Ms Vallee Residence • 1 alert',
                unexpectedToken: null,
                forbiddenTranscriptSnippets: const <String>[
                  'ONYX ONBOARDING PENDING',
                  telegramHighRiskEscalationCopy,
                  telegramRouteFallbackCopy,
                ],
                extraExpected: const <String>[],
                expectOnboardingIntake: true,
                expectHeadingAfterOnboarding: false,
                events: <DispatchEvent>[
                  IntelligenceReceived(
                    eventId:
                        'admin-onboarding-all-sites-intel-1-${scenario.firstUpdateId}',
                    sequence: 1,
                    version: 1,
                    occurredAt: latestSafe
                        .subtract(const Duration(minutes: 3))
                        .toUtc(),
                    intelligenceId: 'INT-ONBOARD-ALL-1-${scenario.firstUpdateId}',
                    provider: 'hikvision-dvr',
                    sourceType: 'dvr',
                    externalId: 'evt-onboard-all-1-${scenario.firstUpdateId}',
                    clientId: 'CLIENT-MS-VALLEE',
                    regionId: 'REGION-GAUTENG',
                    siteId: 'SITE-SANDTON-ESTATE',
                    headline: 'Boundary alert',
                    summary: 'Boundary alert detected.',
                    riskScore: 62,
                    canonicalHash: 'onboard-all-hash-1-${scenario.firstUpdateId}',
                  ),
                  IntelligenceReceived(
                    eventId:
                        'admin-onboarding-all-sites-intel-2-${scenario.firstUpdateId}',
                    sequence: 2,
                    version: 1,
                    occurredAt: latestSafe
                        .subtract(const Duration(minutes: 2))
                        .toUtc(),
                    intelligenceId: 'INT-ONBOARD-ALL-2-${scenario.firstUpdateId}',
                    provider: 'hikvision-dvr',
                    sourceType: 'dvr',
                    externalId: 'evt-onboard-all-2-${scenario.firstUpdateId}',
                    clientId: 'CLIENT-MS-VALLEE',
                    regionId: 'REGION-GAUTENG',
                    siteId: 'SITE-SANDTON-ESTATE',
                    headline: 'Gate alert',
                    summary: 'Unexpected person detected.',
                    riskScore: 70,
                    canonicalHash: 'onboard-all-hash-2-${scenario.firstUpdateId}',
                  ),
                  IntelligenceReceived(
                    eventId:
                        'admin-onboarding-all-sites-intel-3-${scenario.firstUpdateId}',
                    sequence: 3,
                    version: 1,
                    occurredAt: latestSafe
                        .subtract(const Duration(minutes: 1))
                        .toUtc(),
                    intelligenceId: 'INT-ONBOARD-ALL-3-${scenario.firstUpdateId}',
                    provider: 'hikvision-dvr',
                    sourceType: 'dvr',
                    externalId: 'evt-onboard-all-3-${scenario.firstUpdateId}',
                    clientId: 'CLIENT-MS-VALLEE',
                    regionId: 'REGION-GAUTENG',
                    siteId: 'SITE-MS-VALLEE-RESIDENCE',
                    headline: 'Driveway alert',
                    summary: 'Vehicle detected near the driveway.',
                    riskScore: 58,
                    canonicalHash: 'onboard-all-hash-3-${scenario.firstUpdateId}',
                  ),
                ],
              ),
            (
              prompts: const <String>[
                'Create new client Akhalawayas Robertsham',
                'Do we have police activity tonight?',
              ],
              firstUpdateId: 440873,
              expectedHeading: "Tonight's incidents for MS Vallee Residence:",
              expectedToken: 'DSP-ONBOARD-TONIGHT',
              unexpectedToken: 'DSP-ONBOARD-OLD',
              forbiddenTranscriptSnippets: const <String>[
                telegramHighRiskEscalationCopy,
                'ONYX ONBOARDING PENDING',
                'I could not route that request yet.',
              ],
              extraExpected: const <String>[],
              expectOnboardingIntake: true,
              expectHeadingAfterOnboarding: false,
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'admin-telegram-mixed-tonight-a',
                  sequence: 1,
                  version: 1,
                  occurredAt: latestInWindow.toUtc(),
                  dispatchId: 'DSP-ONBOARD-TONIGHT',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
                DecisionCreated(
                  eventId: 'admin-telegram-mixed-tonight-old',
                  sequence: 2,
                  version: 1,
                  occurredAt: start.subtract(const Duration(minutes: 12)).toUtc(),
                  dispatchId: 'DSP-ONBOARD-OLD',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
              ],
            ),
            (
              prompts: const <String>[
                'Create new client Akhalawayas Robertsham',
                'What changed across all sites tonight?',
              ],
              firstUpdateId: 440874,
              expectedHeading: "Tonight's incidents for CLIENT-MS-VALLEE:",
              expectedToken: 'DSP-ONBOARD-ALL-TONIGHT-1',
              unexpectedToken: 'DSP-ONBOARD-ALL-TONIGHT-OLD',
              forbiddenTranscriptSnippets: const <String>[
                'ONYX ONBOARDING PENDING',
                telegramHighRiskEscalationCopy,
                telegramRouteFallbackCopy,
              ],
              extraExpected: const <String>['DSP-ONBOARD-ALL-TONIGHT-2'],
              expectOnboardingIntake: true,
              expectHeadingAfterOnboarding: false,
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'admin-telegram-all-sites-tonight-a',
                  sequence: 1,
                  version: 1,
                  occurredAt: latestInWindow.toUtc(),
                  dispatchId: 'DSP-ONBOARD-ALL-TONIGHT-1',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
                DecisionCreated(
                  eventId: 'admin-telegram-all-sites-tonight-b',
                  sequence: 2,
                  version: 1,
                  occurredAt: latestInWindow
                      .subtract(const Duration(minutes: 5))
                      .toUtc(),
                  dispatchId: 'DSP-ONBOARD-ALL-TONIGHT-2',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON-ESTATE',
                ),
                DecisionCreated(
                  eventId: 'admin-telegram-all-sites-tonight-old',
                  sequence: 3,
                  version: 1,
                  occurredAt: start.subtract(const Duration(minutes: 9)).toUtc(),
                  dispatchId: 'DSP-ONBOARD-ALL-TONIGHT-OLD',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON-ESTATE',
                ),
              ],
            ),
            (
              prompts: const <String>[
                'Create new client Akhalawayas Robertsham',
                'Any medical incidents here',
              ],
              firstUpdateId: 440874,
              expectedHeading: 'Unresolved incidents in MS Vallee Residence:',
              expectedToken: 'INC-DSP-ONBOARD-UNRESOLVED',
              unexpectedToken: null,
              forbiddenTranscriptSnippets: const <String>[
                telegramHighRiskEscalationCopy,
                'ONYX ONBOARDING PENDING',
                'I could not route that request yet.',
              ],
              extraExpected: const <String>[],
              expectOnboardingIntake: true,
              expectHeadingAfterOnboarding: false,
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'admin-telegram-mixed-unresolved-a',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 6)),
                  dispatchId: 'DSP-ONBOARD-UNRESOLVED',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
              ],
            ),
          ];

      for (var index = 0; index < expandedCases.length; index += 1) {
        final scenario = expandedCases[index];
        final sentTranscript = await sendAdminTelegramConversationThroughRoute(
          tester,
          appKey: ValueKey('admin-telegram-onboarding-read-matrix-$index'),
          prompts: scenario.prompts,
          firstUpdateId: scenario.firstUpdateId,
          initialStoreEventsOverride: scenario.events,
        );

        expectDeterministicTelegramFollowUpReply(
          sentTranscript,
          expectedHeading: scenario.expectedHeading,
          expectedToken: scenario.expectedToken,
          unexpectedToken: scenario.unexpectedToken,
          forbiddenTranscriptSnippets: scenario.forbiddenTranscriptSnippets,
        );
        for (final text in scenario.extraExpected) {
          expect(sentTranscript, contains(text), reason: scenario.prompts.last);
        }
        expect(
          RegExp('ONYX ONBOARDING INTAKE').allMatches(sentTranscript).length,
          scenario.expectOnboardingIntake ? 1 : 0,
          reason: scenario.prompts.last,
        );
        if (scenario.expectHeadingAfterOnboarding) {
          expect(
            sentTranscript.indexOf(scenario.expectedHeading),
            greaterThan(sentTranscript.indexOf('ONYX ONBOARDING INTAKE')),
            reason: scenario.prompts.last,
          );
        }
      }
    },
  );

  testWidgets(
    'onyx app keeps approved telegram onboarding reflection, follow-up, and bridge workflows deterministic across admin surfaces',
    (tester) async {
      const syncSummary =
          'Telegram onboarding synced locally: CLIENT-AKHALAWAYAS-ROBERTSHAM / SITE-ROBERTSHAM-ESTATE.';
      final cases =
          <({
            ValueKey<String> appKey,
            AdministrationPageTab initialAdminTab,
            int createUpdateId,
            int approveUpdateId,
            List<String> expectedTranscriptTexts,
            String? expectedExactText,
            String? expectedContainingText,
            String? expectedKey,
            List<String> extraContainingTexts,
          })>[
            (
              appKey: const ValueKey(
                'admin-telegram-onboarding-directory-reflect-app',
              ),
              initialAdminTab: AdministrationPageTab.clients,
              createUpdateId: 44091,
              approveUpdateId: 44092,
              expectedTranscriptTexts: const <String>[],
              expectedExactText: null,
              expectedContainingText: syncSummary,
              expectedKey: 'admin-edit-client-CLIENT-AKHALAWAYAS-ROBERTSHAM',
              extraContainingTexts: const <String>[
                'Akhalawayas Robertsham',
                'CLIENT-AKHALAWAYAS-ROBERTSHAM',
              ],
            ),
            (
              appKey: const ValueKey(
                'admin-telegram-onboarding-site-directory-reflect-app',
              ),
              initialAdminTab: AdministrationPageTab.sites,
              createUpdateId: 44093,
              approveUpdateId: 44094,
              expectedTranscriptTexts: const <String>[],
              expectedExactText: null,
              expectedContainingText: syncSummary,
              expectedKey: 'admin-edit-site-SITE-ROBERTSHAM-ESTATE',
              extraContainingTexts: const <String>[
                'Robertsham Estate',
                'SITE-ROBERTSHAM-ESTATE',
              ],
            ),
            (
              appKey: const ValueKey(
                'admin-telegram-onboarding-system-retarget-app',
              ),
              initialAdminTab: AdministrationPageTab.system,
              createUpdateId: 44089,
              approveUpdateId: 44090,
              expectedTranscriptTexts: const <String>[
                'ONYX ONBOARDING APPROVED',
                '• Scope in focus: CLIENT-AKHALAWAYAS-ROBERTSHAM / SITE-ROBERTSHAM-ESTATE',
                '• Admin target updated for follow-up commands.',
                '• Live client/site record creation is in local mode only. Target scope was updated locally.',
                'Ask: "check the system" or "show dispatches today".',
              ],
              expectedExactText:
                  'Target CLIENT-AKHALAWAYAS-ROBERTSHAM / SITE-ROBERTSHAM-ESTATE',
              expectedContainingText: syncSummary,
              expectedKey: null,
              extraContainingTexts: const <String>[],
            ),
          ];

      for (var index = 0; index < cases.length; index += 1) {
        final scenario = cases[index];
        final bridge = await pumpApprovedAdminTelegramOnboardingRoute(
          tester,
          appKey: scenario.appKey,
          initialAdminTab: scenario.initialAdminTab,
          createUpdateId: scenario.createUpdateId,
          approveUpdateId: scenario.approveUpdateId,
        );

        if (scenario.expectedTranscriptTexts.isNotEmpty) {
          final sentTranscript = bridge.sentMessages
              .map((message) => message.text)
              .join('\n---\n');
          for (final text in scenario.expectedTranscriptTexts) {
            expect(sentTranscript, contains(text));
          }
        }

        if (scenario.expectedKey case final key?) {
          expect(find.byKey(ValueKey(key)), findsOneWidget);
        }
        if (scenario.expectedExactText case final text?) {
          expect(find.text(text), findsOneWidget);
        }
        if (scenario.expectedContainingText case final text?) {
          expect(find.textContaining(text), findsOneWidget);
        }
        for (final text in scenario.extraContainingTexts) {
          expect(find.textContaining(text), findsWidgets);
        }
      }

      final followupCases =
          <({
            ValueKey<String> appKey,
            int createUpdateId,
            int approveUpdateId,
            String buttonKey,
            String expectedTitle,
            String expectedRecoveryText,
            List<String> expectedSeedKeys,
            List<({String label, String value})> expectedFields,
          })>[
            (
              appKey: const ValueKey(
                'admin-telegram-onboarding-followup-open-client-app',
              ),
              createUpdateId: 44097,
              approveUpdateId: 44098,
              buttonKey: 'admin-system-telegram-onboarding-open-client',
              expectedTitle: 'New Client Onboarding',
              expectedRecoveryText:
                  'Telegram-approved client intake is staged and recoverable.',
              expectedSeedKeys: const <String>[
                'client-onboarding-command-deck',
                'client-onboarding-telegram-seed-shell',
                'client-onboarding-telegram-seed-messaging',
                'client-onboarding-telegram-seed-brief',
              ],
              expectedFields: const <({String label, String value})>[
                (
                  label: 'Client ID (e.g. CLIENT-001)',
                  value: 'CLIENT-AKHALAWAYAS-ROBERTSHAM',
                ),
                (
                  label: 'Legal Entity Name',
                  value: 'Akhalawayas Robertsham',
                ),
                (
                  label: 'Primary Contact Name',
                  value: 'John Smith',
                ),
              ],
            ),
            (
              appKey: const ValueKey(
                'admin-telegram-onboarding-followup-open-site-app',
              ),
              createUpdateId: 44099,
              approveUpdateId: 44100,
              buttonKey: 'admin-system-telegram-onboarding-open-site',
              expectedTitle: 'New Site Onboarding',
              expectedRecoveryText:
                  'Telegram-approved site intake is staged and recoverable.',
              expectedSeedKeys: const <String>[
                'site-onboarding-command-deck',
                'site-onboarding-telegram-seed-shell',
                'site-onboarding-telegram-seed-location',
                'site-onboarding-telegram-seed-risk',
                'site-onboarding-telegram-seed-bridge-brief',
                'site-onboarding-telegram-seed-open-camera-bridge',
              ],
              expectedFields: const <({String label, String value})>[
                (
                  label: 'Site ID (e.g. SITE-SANDTON)',
                  value: 'SITE-ROBERTSHAM-ESTATE',
                ),
                (
                  label: 'Site Name',
                  value: 'Robertsham Estate',
                ),
                (
                  label: 'Physical Address',
                  value: 'Robertsham Estate',
                ),
              ],
            ),
          ];

      for (var index = 0; index < followupCases.length; index += 1) {
        final scenario = followupCases[index];
        await pumpApprovedAdminTelegramOnboardingRoute(
          tester,
          appKey: scenario.appKey,
          initialAdminTab: AdministrationPageTab.system,
          createUpdateId: scenario.createUpdateId,
          approveUpdateId: scenario.approveUpdateId,
        );

        final actionButton = find.byKey(ValueKey(scenario.buttonKey));
        await tester.ensureVisible(actionButton);
        await tester.tap(actionButton);
        await tester.pumpAndSettle();

        expect(find.text(scenario.expectedTitle), findsOneWidget);
        expect(find.text(scenario.expectedRecoveryText), findsOneWidget);
        expect(find.text('VERIFY TELEGRAM INTAKE'), findsOneWidget);
        for (final key in scenario.expectedSeedKeys) {
          expect(find.byKey(ValueKey(key)), findsOneWidget);
        }
        for (final field in scenario.expectedFields) {
          expect(
            tester
                .widget<TextField>(
                  find.widgetWithText(TextField, field.label),
                )
                .controller!
                .text,
            field.value,
          );
        }
      }

      final restartCases =
          <({
            ValueKey<String> firstAppKey,
            ValueKey<String> secondAppKey,
            int createUpdateId,
            int approveUpdateId,
            String buttonKey,
            String expectedTitle,
            List<({String label, String value})> expectedFields,
          })>[
            (
              firstAppKey: const ValueKey(
                'admin-telegram-onboarding-restart-prefill-first-app',
              ),
              secondAppKey: const ValueKey(
                'admin-telegram-onboarding-restart-prefill-second-app',
              ),
              createUpdateId: 44089,
              approveUpdateId: 44090,
              buttonKey: 'admin-system-telegram-onboarding-open-client',
              expectedTitle: 'New Client Onboarding',
              expectedFields: const <({String label, String value})>[
                (
                  label: 'Client ID (e.g. CLIENT-001)',
                  value: 'CLIENT-AKHALAWAYAS-ROBERTSHAM',
                ),
                (
                  label: 'Legal Entity Name',
                  value: 'Akhalawayas Robertsham',
                ),
              ],
            ),
            (
              firstAppKey: const ValueKey(
                'admin-telegram-onboarding-restart-site-prefill-first-app',
              ),
              secondAppKey: const ValueKey(
                'admin-telegram-onboarding-restart-site-prefill-second-app',
              ),
              createUpdateId: 44103,
              approveUpdateId: 44104,
              buttonKey: 'admin-system-telegram-onboarding-open-site',
              expectedTitle: 'New Site Onboarding',
              expectedFields: const <({String label, String value})>[
                (
                  label: 'Site ID (e.g. SITE-SANDTON)',
                  value: 'SITE-ROBERTSHAM-ESTATE',
                ),
                (
                  label: 'Site Name',
                  value: 'Robertsham Estate',
                ),
                (
                  label: 'Physical Address',
                  value: 'Robertsham Estate',
                ),
              ],
            ),
          ];

      for (var index = 0; index < restartCases.length; index += 1) {
        final scenario = restartCases[index];
        await restoreApprovedTelegramOnboardingAfterRestart(
          tester,
          firstAppKey: scenario.firstAppKey,
          secondAppKey: scenario.secondAppKey,
          createUpdateId: scenario.createUpdateId,
          approveUpdateId: scenario.approveUpdateId,
        );

        final actionButton = find.byKey(ValueKey(scenario.buttonKey));
        expect(actionButton, findsOneWidget);
        await tester.ensureVisible(actionButton);
        await tester.tap(actionButton);
        await tester.pumpAndSettle();

        expect(find.text(scenario.expectedTitle), findsOneWidget);
        for (final field in scenario.expectedFields) {
          expect(
            tester
                .widget<TextField>(
                  find.widgetWithText(TextField, field.label),
                )
                .controller!
                .text,
            field.value,
          );
        }
      }

      final thirdBridge = _RecordingTelegramBridgeStub();
      await restoreApprovedTelegramOnboardingAfterRestart(
        tester,
        firstAppKey: const ValueKey(
          'admin-telegram-onboarding-dismiss-first-app',
        ),
        secondAppKey: const ValueKey(
          'admin-telegram-onboarding-dismiss-second-app',
        ),
        createUpdateId: 44105,
        approveUpdateId: 44106,
      );

      final dismissButton = find.byKey(
        const ValueKey('admin-system-telegram-onboarding-dismiss-followup'),
      );
      expect(dismissButton, findsOneWidget);
      await tester.ensureVisible(dismissButton);
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-system-telegram-onboarding-followup')),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Telegram onboarding synced locally: CLIENT-AKHALAWAYAS-ROBERTSHAM / SITE-ROBERTSHAM-ESTATE.',
        ),
        findsOneWidget,
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-telegram-onboarding-dismiss-third-app'),
        initialAdminTab: AdministrationPageTab.system,
        telegramBridgeServiceOverride: thirdBridge,
        telegramAdminChatIdOverride: 'test-admin-chat',
      );

      expect(
        find.byKey(const ValueKey('admin-system-telegram-onboarding-followup')),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Telegram onboarding synced locally: CLIENT-AKHALAWAYAS-ROBERTSHAM / SITE-ROBERTSHAM-ESTATE.',
        ),
        findsOneWidget,
      );

      const bridgeService = _RouteFakeCameraBridgeHealthService();
      final bridgeStatus = OnyxAgentCameraBridgeStatus(
        enabled: true,
        running: true,
        authRequired: true,
        endpoint: Uri(scheme: 'http', host: '127.0.0.1', port: 11634),
        statusLabel: 'Live',
        detail:
            'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
      );

      await openCameraBridgeFromApprovedTelegramOnboarding(
        tester,
        appKey: const ValueKey('admin-telegram-onboarding-open-ops-app'),
        telegramBridgeServiceOverride: _RecordingTelegramBridgeStub(),
        createUpdateId: 44109,
        approveUpdateId: 44110,
      );

      expect(find.text('New Site Onboarding'), findsNothing);
      expect(
        find.text('Focused camera bridge setup for SITE-ROBERTSHAM-ESTATE.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-system-camera-bridge-telegram-seed')),
        findsOneWidget,
      );
      expect(find.text('TELEGRAM BRIDGE SEED READY'), findsOneWidget);
      expect(
        find.text('SITE-ROBERTSHAM-ESTATE • Robertsham Estate'),
        findsOneWidget,
      );
      for (final key in const <String>[
        'admin-system-camera-bridge-telegram-seed-copy',
        'admin-system-camera-bridge-telegram-seed-copy-cctv',
        'admin-system-camera-bridge-telegram-seed-copy-vendor',
        'admin-system-camera-bridge-telegram-seed-open-ops',
        'admin-system-camera-bridge-telegram-seed-poll-cctv',
        'admin-system-camera-bridge-command',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }

      final openOpsButton = find.byKey(
        const ValueKey('admin-system-camera-bridge-telegram-seed-open-ops'),
      );
      await tester.ensureVisible(openOpsButton);
      await tester.tap(openOpsButton);
      await tester.pumpAndSettle();

      expect(find.byType(LiveOperationsPage), findsOneWidget);
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeClientId,
        'CLIENT-AKHALAWAYAS-ROBERTSHAM',
      );
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeSiteId,
        'SITE-ROBERTSHAM-ESTATE',
      );

      for (final scenario in const <({
        ValueKey<String> appKey,
        int approveUpdateId,
        int createUpdateId,
        String seedControlKey,
      })>[
        (
          appKey: ValueKey('admin-telegram-onboarding-vendor-validate-app'),
          createUpdateId: 44117,
          approveUpdateId: 44118,
          seedControlKey:
              'admin-system-camera-bridge-telegram-seed-copy-vendor',
        ),
        (
          appKey: ValueKey('admin-telegram-onboarding-cctv-poll-app'),
          createUpdateId: 44119,
          approveUpdateId: 44120,
          seedControlKey: 'admin-system-camera-bridge-telegram-seed-poll-cctv',
        ),
      ]) {
        await openCameraBridgeFromApprovedTelegramOnboarding(
          tester,
          appKey: scenario.appKey,
          telegramBridgeServiceOverride: _RecordingTelegramBridgeStub(),
          onyxAgentCameraBridgeStatusOverride: bridgeStatus,
          onyxAgentCameraBridgeHealthServiceOverride: bridgeService,
          createUpdateId: scenario.createUpdateId,
          approveUpdateId: scenario.approveUpdateId,
        );

        expect(
          find.byKey(const ValueKey('admin-system-camera-bridge-telegram-seed')),
          findsOneWidget,
        );
        expect(find.byKey(ValueKey(scenario.seedControlKey)), findsOneWidget);
        expect(
          find.byKey(const ValueKey('admin-system-camera-bridge-validate')),
          findsOneWidget,
        );
        expect(find.text('TELEGRAM BRIDGE SEED READY'), findsOneWidget);
      }

      final bridgeCases =
          <({
            ValueKey<String>? firstAppKey,
            ValueKey<String>? secondAppKey,
            int? createUpdateId,
            int? approveUpdateId,
            Map<String, Object?>? savedProgress,
            String statusKey,
          })>[
            (
              firstAppKey: const ValueKey(
                'admin-telegram-bridge-runbook-progress-first-app',
              ),
              secondAppKey: const ValueKey(
                'admin-telegram-bridge-runbook-progress-second-app',
              ),
              createUpdateId: 44111,
              approveUpdateId: 44112,
              savedProgress: null,
              statusKey: 'admin-system-camera-bridge-telegram-runbook-ops-status',
            ),
            (
              firstAppKey: null,
              secondAppKey: null,
              createUpdateId: null,
              approveUpdateId: null,
              savedProgress: <String, Object?>{'cctv_polled': true},
              statusKey: 'admin-system-camera-bridge-telegram-runbook-poll-status',
            ),
            (
              firstAppKey: null,
              secondAppKey: null,
              createUpdateId: null,
              approveUpdateId: null,
              savedProgress: <String, Object?>{'vendor_validated': true},
              statusKey:
                  'admin-system-camera-bridge-telegram-runbook-validate-status',
            ),
          ];

      for (var index = 0; index < bridgeCases.length; index += 1) {
        final scenario = bridgeCases[index];
        if (scenario.savedProgress case final progress?) {
          await prepareAdminRouteTest(tester);
          await saveApprovedTelegramBridgeRuntimeState(progress: progress);
          await pumpAdminRouteApp(
            tester,
            key: ValueKey('admin-telegram-bridge-progress-restore-app-$index'),
            initialAdminTab: AdministrationPageTab.system,
          );
        } else {
          final firstBridge = _RecordingTelegramBridgeStub();
          final secondBridge = _RecordingTelegramBridgeStub();
          await openCameraBridgeFromApprovedTelegramOnboarding(
            tester,
            appKey: scenario.firstAppKey!,
            telegramBridgeServiceOverride: firstBridge,
            createUpdateId: scenario.createUpdateId!,
            approveUpdateId: scenario.approveUpdateId!,
          );

          final openOpsButton = find.byKey(
            const ValueKey('admin-system-camera-bridge-telegram-seed-open-ops'),
          );
          expect(openOpsButton, findsOneWidget);
          await tester.ensureVisible(openOpsButton);
          await tester.tap(openOpsButton);
          await tester.pumpAndSettle();

          expect(find.byType(LiveOperationsPage), findsOneWidget);

          await pumpAdminRouteApp(
            tester,
            key: scenario.secondAppKey!,
            initialAdminTab: AdministrationPageTab.system,
            telegramBridgeServiceOverride: secondBridge,
            telegramAdminChatIdOverride: 'test-admin-chat',
          );
        }

        expect(
          find.descendant(
            of: find.byKey(ValueKey(scenario.statusKey)),
            matching: find.text('Done'),
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('onyx app keeps the common admin telegram prompt matrix stable', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final localNow = now.toLocal();
    final end = DateTime(localNow.year, localNow.month, localNow.day, 6);
    final start = DateTime(
      end.year,
      end.month,
      end.day,
    ).subtract(const Duration(days: 1)).add(const Duration(hours: 18));
    final latestInWindow = localNow.isBefore(end)
        ? localNow.subtract(const Duration(minutes: 1))
        : end.subtract(const Duration(minutes: 5));
    final latestSafe = localNow.subtract(const Duration(minutes: 1));
    final cases =
        <
          ({
            String prompt,
            List<String> expected,
            List<String> forbidden,
            int updateId,
            DateTime? sentAtUtc,
            String chatType,
            List<DispatchEvent> events,
          })
        >[
          (
            prompt: 'Check the system',
            expected: const <String>['ONYX OPS'],
            forbidden: const <String>[],
            updateId: 44101,
            sentAtUtc: null,
            chatType: 'private',
            events: const <DispatchEvent>[],
          ),
          (
            prompt: 'brief ops',
            expected: const <String>[
              'ONYX BRIEF',
              'Scope In Focus',
              'Ask Next',
              'show unresolved incidents',
            ],
            forbidden: const <String>['I could not route that request yet.'],
            updateId: 44102,
            sentAtUtc: null,
            chatType: 'private',
            events: const <DispatchEvent>[],
          ),
          (
            prompt: 'what do the feeds show',
            expected: const <String>['ONYX OPS', 'CCTV'],
            forbidden: const <String>[],
            updateId: 44103,
            sentAtUtc: null,
            chatType: 'private',
            events: const <DispatchEvent>[],
          ),
          (
            prompt: 'what changed today',
            expected: const <String>[
              'ONYX BRIEF',
              'Scope In Focus',
              'Dispatches:',
              'show dispatches today',
            ],
            forbidden: const <String>['I could not route that request yet.'],
            updateId: 44052,
            sentAtUtc: null,
            chatType: 'private',
            events: const <DispatchEvent>[],
          ),
          (
            prompt: 'review cameras',
            expected: const <String>['ONYX OPS', 'CCTV'],
            forbidden: const <String>[],
            updateId: 44053,
            sentAtUtc: null,
            chatType: 'private',
            events: const <DispatchEvent>[],
          ),
          (
            prompt: 'Do we have police activity tonight?',
            expected: const <String>[
              "Tonight's incidents for MS Vallee Residence:",
              'DSP-AMIXED-TONIGHT',
            ],
            forbidden: const <String>['DSP-AMIXED-OLD'],
            updateId: 44106,
            sentAtUtc: latestInWindow.toUtc(),
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-telegram-mixed-tonight-1',
                sequence: 1,
                version: 1,
                occurredAt: latestInWindow.toUtc(),
                dispatchId: 'DSP-AMIXED-TONIGHT',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              DecisionCreated(
                eventId: 'admin-telegram-mixed-tonight-old',
                sequence: 2,
                version: 1,
                occurredAt: start.subtract(const Duration(minutes: 12)).toUtc(),
                dispatchId: 'DSP-AMIXED-OLD',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ],
          ),
          (
            prompt: 'Police activity at MS Vallee tonight?',
            expected: const <String>[
              "Tonight's incidents for MS Vallee Residence:",
              'DSP-AMIXED-SCOPED-TONIGHT',
            ],
            forbidden: const <String>['DSP-AMIXED-SCOPED-OLD'],
            updateId: 44107,
            sentAtUtc: latestInWindow.toUtc(),
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-telegram-mixed-scoped-tonight-1',
                sequence: 1,
                version: 1,
                occurredAt: latestInWindow.toUtc(),
                dispatchId: 'DSP-AMIXED-SCOPED-TONIGHT',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              DecisionCreated(
                eventId: 'admin-telegram-mixed-scoped-tonight-old',
                sequence: 2,
                version: 1,
                occurredAt: start.subtract(const Duration(minutes: 8)).toUtc(),
                dispatchId: 'DSP-AMIXED-SCOPED-OLD',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ],
          ),
          (
            prompt: 'Do we have police activity',
            expected: const <String>[
              'Unresolved incidents in MS Vallee Residence:',
              'INC-DSP-AMIXED-UNRESOLVED',
            ],
            forbidden: const <String>[],
            updateId: 44108,
            sentAtUtc: now,
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-telegram-mixed-unresolved-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 6)),
                dispatchId: 'DSP-AMIXED-UNRESOLVED',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ],
          ),
          (
            prompt: 'Check tonights breaches',
            expected: const <String>[
              'No incidents landed tonight in MS Vallee Residence.',
            ],
            forbidden: const <String>[],
            updateId: 44104,
            sentAtUtc: null,
            chatType: 'private',
            events: const <DispatchEvent>[],
          ),
          (
            prompt: 'Check tonights breaches',
            expected: const <String>[
              "Tonight's incidents for MS Vallee Residence:",
              'DSP-551',
            ],
            forbidden: const <String>['DSP-OLD'],
            updateId: 4404,
            sentAtUtc: now,
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-telegram-tonight-1',
                sequence: 1,
                version: 1,
                occurredAt: latestInWindow.toUtc(),
                dispatchId: 'DSP-551',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              DecisionCreated(
                eventId: 'admin-telegram-tonight-old',
                sequence: 2,
                version: 1,
                occurredAt: start.subtract(const Duration(minutes: 12)).toUtc(),
                dispatchId: 'DSP-OLD',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ],
          ),
          (
            prompt: 'Create new client Akhalawayas Robertsham',
            expected: const <String>['ONYX ONBOARDING INTAKE'],
            forbidden: const <String>[],
            updateId: 44105,
            sentAtUtc: null,
            chatType: 'private',
            events: const <DispatchEvent>[],
          ),
          (
            prompt: 'show all sites',
            expected: const <String>[
              'ONYX SITES',
              'Ms Vallee Residence',
              'Robertsham Estate',
            ],
            forbidden: const <String>['I could not route that request yet.'],
            updateId: 44011,
            sentAtUtc: now,
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-telegram-sites-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 9)),
                dispatchId: 'DSP-SITES-1',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              DecisionCreated(
                eventId: 'admin-telegram-sites-2',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 6)),
                dispatchId: 'DSP-SITES-2',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-ROBERTSHAM-ESTATE',
              ),
            ],
          ),
          (
            prompt: 'Show dispatches today',
            expected: const <String>[
              'Today\'s dispatches for MS Vallee Residence:',
              'DSP-401',
            ],
            forbidden: const <String>[],
            updateId: 4401,
            sentAtUtc: now,
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-telegram-decision-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 9)),
                dispatchId: 'DSP-401',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ],
          ),
          (
            prompt: 'Which site has most alerts this week',
            expected: const <String>[
              "This week's alert leader: Sandton Estate (2 alerts)",
              'Ms Vallee Residence • 1 alert',
            ],
            forbidden: const <String>[],
            updateId: 4402,
            sentAtUtc: latestSafe.toUtc(),
            chatType: 'private',
            events: <DispatchEvent>[
              IntelligenceReceived(
                eventId: 'admin-intel-1',
                sequence: 1,
                version: 1,
                occurredAt: latestSafe.subtract(const Duration(minutes: 3)).toUtc(),
                intelligenceId: 'INT-ADMIN-1',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-admin-1',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON-ESTATE',
                headline: 'Boundary alert',
                summary: 'Boundary alert detected.',
                riskScore: 62,
                canonicalHash: 'admin-hash-1',
              ),
              IntelligenceReceived(
                eventId: 'admin-intel-2',
                sequence: 2,
                version: 1,
                occurredAt: latestSafe.subtract(const Duration(minutes: 2)).toUtc(),
                intelligenceId: 'INT-ADMIN-2',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-admin-2',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON-ESTATE',
                headline: 'Gate alert',
                summary: 'Unexpected person detected.',
                riskScore: 70,
                canonicalHash: 'admin-hash-2',
              ),
              IntelligenceReceived(
                eventId: 'admin-intel-3',
                sequence: 3,
                version: 1,
                occurredAt: latestSafe.subtract(const Duration(minutes: 1)).toUtc(),
                intelligenceId: 'INT-ADMIN-3',
                provider: 'hikvision-dvr',
                sourceType: 'dvr',
                externalId: 'evt-admin-3',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
                headline: 'Driveway alert',
                summary: 'Vehicle detected near the driveway.',
                riskScore: 58,
                canonicalHash: 'admin-hash-3',
              ),
            ],
          ),
          for (final scenario in <({String prompt, int updateId})>[
            (
              prompt: 'Which site has most alerts across all sites this week?',
              updateId: 44029,
            ),
            (
              prompt: 'Top site across all properties this week?',
              updateId: 44030,
            ),
          ])
            (
              prompt: scenario.prompt,
              expected: const <String>[
                "This week's alert leader: Sandton Estate (2 alerts)",
                'Ms Vallee Residence • 1 alert',
              ],
              forbidden: const <String>['Robertsham Estate'],
              updateId: scenario.updateId,
              sentAtUtc: latestSafe.toUtc(),
              chatType: 'private',
              events: <DispatchEvent>[
                IntelligenceReceived(
                  eventId: 'admin-all-sites-intel-1-${scenario.updateId}',
                  sequence: 1,
                  version: 1,
                  occurredAt: latestSafe
                      .subtract(const Duration(minutes: 4))
                      .toUtc(),
                  intelligenceId: 'INT-ADMIN-ALL-1-${scenario.updateId}',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-admin-all-1-${scenario.updateId}',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON-ESTATE',
                  headline: 'Boundary alert',
                  summary: 'Boundary alert detected.',
                  riskScore: 62,
                  canonicalHash: 'admin-all-hash-1-${scenario.updateId}',
                ),
                IntelligenceReceived(
                  eventId: 'admin-all-sites-intel-2-${scenario.updateId}',
                  sequence: 2,
                  version: 1,
                  occurredAt: latestSafe
                      .subtract(const Duration(minutes: 3))
                      .toUtc(),
                  intelligenceId: 'INT-ADMIN-ALL-2-${scenario.updateId}',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-admin-all-2-${scenario.updateId}',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON-ESTATE',
                  headline: 'Gate alert',
                  summary: 'Unexpected person detected.',
                  riskScore: 70,
                  canonicalHash: 'admin-all-hash-2-${scenario.updateId}',
                ),
                IntelligenceReceived(
                  eventId: 'admin-all-sites-intel-3-${scenario.updateId}',
                  sequence: 3,
                  version: 1,
                  occurredAt: latestSafe
                      .subtract(const Duration(minutes: 2))
                      .toUtc(),
                  intelligenceId: 'INT-ADMIN-ALL-3-${scenario.updateId}',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-admin-all-3-${scenario.updateId}',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                  headline: 'Driveway alert',
                  summary: 'Vehicle detected near the driveway.',
                  riskScore: 58,
                  canonicalHash: 'admin-all-hash-3-${scenario.updateId}',
                ),
                IntelligenceReceived(
                  eventId:
                      'admin-all-sites-intel-other-client-${scenario.updateId}',
                  sequence: 4,
                  version: 1,
                  occurredAt: latestSafe
                      .subtract(const Duration(minutes: 1))
                      .toUtc(),
                  intelligenceId: 'INT-ADMIN-ALL-OTHER-${scenario.updateId}',
                  provider: 'hikvision-dvr',
                  sourceType: 'dvr',
                  externalId: 'evt-admin-all-other-${scenario.updateId}',
                  clientId: 'CLIENT-AKHALAWAYAS-ROBERTSHAM',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-ROBERTSHAM-ESTATE',
                  headline: 'Perimeter alert',
                  summary: 'Unexpected activity at the fence.',
                  riskScore: 73,
                  canonicalHash: 'admin-all-hash-other-${scenario.updateId}',
                ),
              ],
            ),
          (
            prompt: 'Show unresolved incidents',
            expected: const <String>[
              'Unresolved incidents in MS Vallee Residence:',
              'INC-DSP-702',
            ],
            forbidden: const <String>['INC-DSP-701', 'INC-DSP-703'],
            updateId: 4403,
            sentAtUtc: now,
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-unresolved-1',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 18)),
                dispatchId: 'DSP-701',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              DecisionCreated(
                eventId: 'admin-unresolved-2',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 11)),
                dispatchId: 'DSP-702',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              IncidentClosed(
                eventId: 'admin-unresolved-closed-1',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 6)),
                dispatchId: 'DSP-701',
                resolutionType: 'all_clear',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              DecisionCreated(
                eventId: 'admin-unresolved-other-site',
                sequence: 4,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'DSP-703',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON-ESTATE',
              ),
            ],
          ),
          (
            prompt: 'Dispatches across all sites today?',
            expected: const <String>[
              'Today\'s dispatches for CLIENT-MS-VALLEE:',
              'DSP-ALL-DISPATCH-1',
              'DSP-ALL-DISPATCH-2',
            ],
            forbidden: const <String>['DSP-ALL-DISPATCH-OTHER'],
            updateId: 44038,
            sentAtUtc: now,
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-all-sites-dispatch-a',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 9)),
                dispatchId: 'DSP-ALL-DISPATCH-1',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              DecisionCreated(
                eventId: 'admin-all-sites-dispatch-b',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 5)),
                dispatchId: 'DSP-ALL-DISPATCH-2',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON-ESTATE',
              ),
              DecisionCreated(
                eventId: 'admin-all-sites-dispatch-other-client',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 3)),
                dispatchId: 'DSP-ALL-DISPATCH-OTHER',
                clientId: 'CLIENT-AKHALAWAYAS-ROBERTSHAM',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-ROBERTSHAM-ESTATE',
              ),
            ],
          ),
          (
            prompt: 'Breaches across all sites?',
            expected: const <String>[
              'Unresolved incidents in CLIENT-MS-VALLEE:',
              'INC-DSP-ALL-SCOPE-2',
            ],
            forbidden: const <String>[
              'INC-DSP-ALL-SCOPE-1',
              'INC-DSP-OTHER-CLIENT',
            ],
            updateId: 44037,
            sentAtUtc: now,
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-all-sites-unresolved-a',
                sequence: 1,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 7)),
                dispatchId: 'DSP-ALL-SCOPE-1',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              DecisionCreated(
                eventId: 'admin-all-sites-unresolved-b',
                sequence: 2,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 5)),
                dispatchId: 'DSP-ALL-SCOPE-2',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON-ESTATE',
              ),
              DecisionCreated(
                eventId: 'admin-all-sites-unresolved-c',
                sequence: 3,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 4)),
                dispatchId: 'DSP-OTHER-CLIENT',
                clientId: 'CLIENT-AKHALAWAYAS-ROBERTSHAM',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-ROBERTSHAM-ESTATE',
              ),
              IncidentClosed(
                eventId: 'admin-all-sites-unresolved-close',
                sequence: 4,
                version: 1,
                occurredAt: now.subtract(const Duration(minutes: 2)),
                dispatchId: 'DSP-ALL-SCOPE-1',
                resolutionType: 'all_clear',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ],
          ),
          (
            prompt: 'Police activity across Vallee sites tonight?',
            expected: const <String>[
              "Tonight's incidents for CLIENT-MS-VALLEE:",
              'DSP-ALL-TONIGHT-1',
              'DSP-ALL-TONIGHT-2',
            ],
            forbidden: const <String>[
              'DSP-ALL-TONIGHT-OLD',
              'DSP-ALL-TONIGHT-OTHER',
            ],
            updateId: 44055,
            sentAtUtc: latestInWindow.toUtc(),
            chatType: 'private',
            events: <DispatchEvent>[
              DecisionCreated(
                eventId: 'admin-all-sites-tonight-a',
                sequence: 1,
                version: 1,
                occurredAt: latestInWindow.toUtc(),
                dispatchId: 'DSP-ALL-TONIGHT-1',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
              DecisionCreated(
                eventId: 'admin-all-sites-tonight-b',
                sequence: 2,
                version: 1,
                occurredAt: latestInWindow
                    .subtract(const Duration(minutes: 6))
                    .toUtc(),
                dispatchId: 'DSP-ALL-TONIGHT-2',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON-ESTATE',
              ),
              DecisionCreated(
                eventId: 'admin-all-sites-tonight-old',
                sequence: 3,
                version: 1,
                occurredAt: start.subtract(const Duration(minutes: 8)).toUtc(),
                dispatchId: 'DSP-ALL-TONIGHT-OLD',
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON-ESTATE',
              ),
              DecisionCreated(
                eventId: 'admin-all-sites-tonight-other-client',
                sequence: 4,
                version: 1,
                occurredAt: latestInWindow.toUtc(),
                dispatchId: 'DSP-ALL-TONIGHT-OTHER',
                clientId: 'CLIENT-AKHALAWAYAS-ROBERTSHAM',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-ROBERTSHAM-ESTATE',
              ),
            ],
          ),
          for (final scenario in <({String prompt, int updateId})>[
            (prompt: 'Check breaches', updateId: 44031),
            (prompt: 'Show breaches', updateId: 44032),
            (prompt: 'Any breaches', updateId: 44033),
            (prompt: 'Breach status', updateId: 44034),
            (prompt: 'Do we have any breaches?', updateId: 44035),
            (prompt: 'Breaches at the site?', updateId: 44036),
          ])
            (
              prompt: scenario.prompt,
              expected: <String>[
                'Unresolved incidents in MS Vallee Residence:',
                'INC-DSP-ABREACH-${scenario.updateId}',
              ],
              forbidden: const <String>[],
              updateId: scenario.updateId,
              sentAtUtc: now,
              chatType: 'private',
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'admin-telegram-breach-open-${scenario.updateId}',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 8)),
                  dispatchId: 'DSP-ABREACH-${scenario.updateId}',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
                DecisionCreated(
                  eventId: 'admin-telegram-breach-closed-${scenario.updateId}',
                  sequence: 2,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 16)),
                  dispatchId: 'DSP-ABREACH-CLOSED-${scenario.updateId}',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
                IncidentClosed(
                  eventId: 'admin-telegram-breach-close-${scenario.updateId}',
                  sequence: 3,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 5)),
                  dispatchId: 'DSP-ABREACH-CLOSED-${scenario.updateId}',
                  resolutionType: 'all_clear',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ],
          ),
          for (final scenario in <({String prompt, int updateId})>[
            (prompt: 'Fire status', updateId: 44041),
            (prompt: 'Medical status', updateId: 44042),
            (prompt: 'Police status', updateId: 44043),
            (prompt: 'Ambulance status', updateId: 44044),
            (prompt: 'Fire update', updateId: 44045),
            (prompt: 'Medical?', updateId: 44046),
            (prompt: 'Police here', updateId: 44047),
            (prompt: 'Ambulnce status', updateId: 44048),
            (prompt: 'Is there a fire?', updateId: 44049),
          ])
            (
              prompt: scenario.prompt,
              expected: <String>[
                'Unresolved incidents in MS Vallee Residence:',
                'INC-DSP-AEMERGENCY-${scenario.updateId}',
              ],
              forbidden: const <String>[],
              updateId: scenario.updateId,
              sentAtUtc: now,
              chatType: 'private',
              events: <DispatchEvent>[
                DecisionCreated(
                  eventId: 'admin-telegram-emergency-open-${scenario.updateId}',
                  sequence: 1,
                  version: 1,
                  occurredAt: now.subtract(const Duration(minutes: 7)),
                  dispatchId: 'DSP-AEMERGENCY-${scenario.updateId}',
                  clientId: 'CLIENT-MS-VALLEE',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                ),
              ],
            ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final scenario = cases[index];
      final sentTranscript = await sendAdminTelegramPromptThroughRoute(
        tester,
        appKey: ValueKey('admin-telegram-matrix-app-$index'),
        prompt: scenario.prompt,
        updateId: scenario.updateId,
        chatType: scenario.chatType,
        sentAtUtc: scenario.sentAtUtc,
        initialStoreEventsOverride: scenario.events,
      );
      for (final text in scenario.expected) {
        expect(sentTranscript, contains(text), reason: scenario.prompt);
      }
      for (final text in scenario.forbidden) {
        expect(sentTranscript, isNot(contains(text)), reason: scenario.prompt);
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
      expect(
        sentTranscript,
        isNot(contains('I can respond directly without slash commands.')),
        reason: scenario.prompt,
      );
    }
  });

  testWidgets('onyx app keeps admin system and camera bridge surfaces deterministic', (
    tester,
  ) async {
    String? copiedPayload;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await prepareAdminRouteTest(tester);
    await saveTelegramAdminRuntimeState({
      'allowed_user_ids_override': <int>[77],
      'target_client_override': 'CLIENT-MS-VALLEE',
      'target_site_override': 'SITE-MS-VALLEE-RESIDENCE',
    });

    await pumpAdminRouteApp(
      tester,
      key: const ValueKey('admin-telegram-wiring-checklist-app'),
      initialAdminTab: AdministrationPageTab.system,
      telegramChatIdOverride: 'test-vallee-chat',
    );

    await openAdminSystemAnchor(tester, 'Telegram Wiring Checklist');

    expect(find.byKey(adminTelegramWiringChecklistPanelKey), findsOneWidget);
    expect(find.text('ONYX Admin Group'), findsOneWidget);
    expect(find.text('Current Client Group'), findsOneWidget);
    expect(find.text('Effective Runtime Snippet'), findsOneWidget);
    expect(find.text('Telegram Prompt Catalog'), findsOneWidget);
    expect(find.text('Recent Live Telegram Asks'), findsOneWidget);
    expect(
      find.textContaining(
        'Admin is currently borrowing the current client group',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('test-vallee-chat'), findsWidgets);
    expect(
      find.textContaining('ONYX_TELEGRAM_ADMIN_CHAT_ID=test-vallee-chat'),
      findsOneWidget,
    );
    expect(
      find.textContaining('ONYX_TELEGRAM_CHAT_ID=test-vallee-chat'),
      findsOneWidget,
    );
    expect(find.text('check the system'), findsOneWidget);
    expect(find.text('check cameras'), findsOneWidget);
    expect(find.text('sleep check'), findsOneWidget);
    expect(
      find.textContaining('No handled prompts yet in this runtime.'),
      findsOneWidget,
    );
    expect(find.text('which site has most alerts this week'), findsOneWidget);
    expect(find.text('check status of Guard001'), findsWidgets);
    expect(
      find.text('Target CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE'),
      findsOneWidget,
    );

    copiedPayload = null;
    await prepareAdminRouteTest(tester);

    await pumpAdminRouteApp(
      tester,
      key: const ValueKey('admin-export-route-app'),
      initialAdminTab: AdministrationPageTab.system,
    );
    await openAdminSystemAnchor(tester, 'System Information');

    final exportButton = find.byKey(const ValueKey('admin-export-data-button'));
    await tester.ensureVisible(exportButton);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('"operator_id"'));
    expect(copiedPayload, contains('"telegram_bridge_health_label"'));
    expect(copiedPayload, contains('"camera_bridge_status_label"'));
    expect(copiedPayload, contains('"camera_bridge_health_status_label"'));
    expect(
      copiedPayload,
      contains('"camera_bridge_health_requested_endpoint"'),
    );
    expect(copiedPayload, contains('"camera_bridge_health_endpoint"'));
    expect(copiedPayload, contains('"camera_bridge_health_reported_endpoint"'));
    expect(copiedPayload, contains('"camera_bridge_health_endpoint_mismatch"'));
    expect(copiedPayload, contains('"camera_bridge_shell_state"'));
    expect(copiedPayload, contains('"camera_bridge_shell_summary"'));
    expect(copiedPayload, contains('"camera_bridge_health_receipt_state"'));
    expect(copiedPayload, contains('"camera_bridge_health_receipt_missing"'));
    expect(
      copiedPayload,
      contains('"camera_bridge_health_receipt_unavailable"'),
    );
    expect(copiedPayload, contains('"camera_bridge_health_receipt_current"'));
    expect(copiedPayload, contains('"camera_bridge_health_receipt_stale"'));
    expect(copiedPayload, contains('"camera_bridge_health_operator_id"'));
    expect(
      copiedPayload,
      contains('"camera_bridge_health_validation_summary"'),
    );
    final exported = jsonDecode(copiedPayload!) as Map<String, dynamic>;
    expect(exported['camera_bridge_shell_state'], 'DISABLED');
    expect(
      exported['camera_bridge_shell_summary'],
      'Enable the local camera bridge if you want LAN workers to post packets into ONYX.',
    );
    expect(exported['camera_bridge_health_receipt_state'], isNull);
    expect(exported['camera_bridge_health_receipt_missing'], false);
    expect(exported['camera_bridge_health_receipt_unavailable'], false);
    expect(exported['camera_bridge_health_receipt_current'], false);
    expect(exported['camera_bridge_health_receipt_stale'], false);
    expect(exported['camera_bridge_health_validation_summary'], isNull);

    final restoredReceiptCases =
        <({
          String appKey,
          DateTime checkedAtUtc,
          String expectedOperatorId,
          String expectedReceiptState,
          String expectedShellState,
          String expectedShellSummary,
          String expectedValidationText,
          bool expectedCurrent,
          bool expectedStale,
        })>[
          (
            appKey: 'admin-export-current-bridge-health-app',
            checkedAtUtc: _freshCameraBridgeCheckedAtUtc(),
            expectedOperatorId: 'OPS-DELTA',
            expectedReceiptState: 'CURRENT',
            expectedShellState: 'READY',
            expectedShellSummary:
                'LAN workers can target http://127.0.0.1:11634/execute and poll http://127.0.0.1:11634/health right now.',
            expectedValidationText: 'Receipt is current.',
            expectedCurrent: true,
            expectedStale: false,
          ),
          (
            appKey: 'admin-export-stale-bridge-health-app',
            checkedAtUtc: _staleCameraBridgeCheckedAtUtc(),
            expectedOperatorId: 'OPS-ECHO',
            expectedReceiptState: 'STALE',
            expectedShellState: 'RECEIPT_STALE',
            expectedShellSummary:
                'Bridge validation receipt is stale. Re-run GET /health before trusting http://127.0.0.1:11634 for LAN worker setup.',
            expectedValidationText:
                'Re-run GET /health before trusting this receipt.',
            expectedCurrent: false,
            expectedStale: true,
          ),
        ];

    for (final scenario in restoredReceiptCases) {
      copiedPayload = null;
      await prepareAdminRouteTest(tester);
      await saveTelegramAdminRuntimeState({
        'camera_bridge_health_snapshot': <String, Object?>{
          'requested_endpoint': 'http://127.0.0.1:11634',
          'health_endpoint': 'http://127.0.0.1:11634/health',
          'reported_endpoint': 'http://127.0.0.1:11634',
          'reachable': true,
          'running': true,
          'status_code': 200,
          'status_label': 'Healthy',
          'detail':
              'GET /health succeeded and the bridge reported packet ingress ready.',
          'execute_path': '/execute',
          'checked_at_utc': scenario.checkedAtUtc.toIso8601String(),
          'operator_id': scenario.expectedOperatorId,
        },
      });

      await pumpAdminRouteApp(
        tester,
        key: ValueKey(scenario.appKey),
        initialAdminTab: AdministrationPageTab.system,
      );
      await openAdminSystemAnchor(tester, 'System Information');

      final restoredReceiptExportButton = find.byKey(
        const ValueKey('admin-export-data-button'),
      );
      await tester.ensureVisible(restoredReceiptExportButton);
      await tester.tap(restoredReceiptExportButton);
      await tester.pumpAndSettle();

      expect(copiedPayload, isNotNull);
      final restoredExported = jsonDecode(copiedPayload!) as Map<String, dynamic>;
      expect(
        restoredExported['camera_bridge_shell_state'],
        scenario.expectedShellState,
      );
      expect(
        restoredExported['camera_bridge_shell_summary'],
        scenario.expectedShellSummary,
      );
      expect(
        restoredExported['camera_bridge_health_receipt_state'],
        scenario.expectedReceiptState,
      );
      expect(restoredExported['camera_bridge_health_receipt_missing'], false);
      expect(
        restoredExported['camera_bridge_health_receipt_unavailable'],
        false,
      );
      expect(
        restoredExported['camera_bridge_health_receipt_current'],
        scenario.expectedCurrent,
      );
      expect(
        restoredExported['camera_bridge_health_receipt_stale'],
        scenario.expectedStale,
      );
      expect(restoredExported['camera_bridge_health_endpoint_mismatch'], false);
      expect(
        restoredExported['camera_bridge_health_operator_id'],
        scenario.expectedOperatorId,
      );
      expect(
        restoredExported['camera_bridge_health_validation_summary'] as String,
        contains(scenario.expectedValidationText),
      );
      expect(
        restoredExported['camera_bridge_health_validation_summary'] as String,
        contains(scenario.expectedOperatorId),
      );
    }

    await prepareAdminRouteTest(tester);

    await pumpAdminRouteApp(
      tester,
      key: const ValueKey('admin-import-route-app'),
      initialAdminTab: AdministrationPageTab.system,
    );
    await openAdminSystemAnchor(tester, 'System Information');

    final importButton = find.byKey(
      const ValueKey('admin-import-csv-button'),
    );
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pumpAndSettle();

    expect(find.text('Import CSV'), findsWidgets);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Import'), findsWidgets);

      await prepareAdminRouteTest(tester);
      await saveTelegramAdminRuntimeState({
        'camera_bridge_health_snapshot': <String, Object?>{
          'requested_endpoint': 'http://127.0.0.1:11634',
          'health_endpoint': 'http://127.0.0.1:11634/health',
          'reported_endpoint': 'http://10.0.0.44:11634',
          'reachable': true,
          'running': true,
          'status_code': 200,
          'status_label': 'Healthy',
          'detail':
              'GET /health succeeded and the bridge reported packet ingress ready. Bridge reported bind http://10.0.0.44:11634 while ONYX probed http://127.0.0.1:11634.',
          'execute_path': '/execute',
          'checked_at_utc': _freshCameraBridgeCheckedAtUtc().toIso8601String(),
          'operator_id': 'OPS-CHARLIE',
        },
      });

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-bridge-health-restore-app'),
        initialAdminTab: AdministrationPageTab.system,
      );
      await openAdminSystemAnchor(tester, 'LOCAL CAMERA BRIDGE');

      expect(
        find.byKey(const ValueKey('admin-system-camera-bridge-health-result')),
        findsOneWidget,
      );
      expect(find.text('HEALTHY'), findsOneWidget);
      expect(find.textContaining('Validated by: OPS-CHARLIE'), findsOneWidget);
      expect(
        find.textContaining('Endpoint mismatch: Detected'),
        findsOneWidget,
      );
      expect(find.text('Bind mismatch'), findsOneWidget);
      expect(
        find.textContaining(
          'Reconcile http://127.0.0.1:11634 vs http://10.0.0.44:11634 before giving this listener to LAN workers.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Probed bind: http://127.0.0.1:11634'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Reported bind: http://10.0.0.44:11634'),
        findsOneWidget,
      );
      expect(
        find.textContaining('POST http://10.0.0.44:11634/execute'),
        findsWidgets,
      );
      expect(
        find.textContaining('GET http://127.0.0.1:11634/health'),
        findsOneWidget,
      );

      await prepareAdminRouteTest(tester);
      await saveTelegramAdminRuntimeState({
        'camera_bridge_health_snapshot': <String, Object?>{
          'requested_endpoint': 'http://127.0.0.1:11634',
          'health_endpoint': 'http://127.0.0.1:11634/health',
          'reported_endpoint': 'http://127.0.0.1:11634',
          'reachable': true,
          'running': true,
          'status_code': 200,
          'status_label': 'Healthy',
          'detail':
              'GET /health succeeded and the bridge reported packet ingress ready.',
          'execute_path': '/execute',
          'checked_at_utc': _freshCameraBridgeCheckedAtUtc().toIso8601String(),
          'operator_id': 'OPS-DELTA',
        },
      });

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-bridge-health-clear-app'),
        initialAdminTab: AdministrationPageTab.system,
      );
      await openAdminSystemAnchor(tester, 'LOCAL CAMERA BRIDGE');

      expect(
        find.byKey(const ValueKey('admin-system-camera-bridge-health-result')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('admin-system-camera-bridge-clear-health')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-system-camera-bridge-health-result')),
        findsNothing,
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-bridge-health-clear-restart-app'),
        initialAdminTab: AdministrationPageTab.system,
      );
      await openAdminSystemAnchor(tester, 'LOCAL CAMERA BRIDGE');

      expect(
        find.byKey(const ValueKey('admin-system-camera-bridge-health-result')),
        findsNothing,
      );

      const bridgeService = _RouteFakeCameraBridgeHealthService();
      final bridgeStatus = OnyxAgentCameraBridgeStatus(
        enabled: true,
        running: true,
        authRequired: true,
        endpoint: Uri(scheme: 'http', host: '127.0.0.1', port: 11634),
        statusLabel: 'Live',
        detail:
            'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
      );

      await prepareAdminRouteTest(tester);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-bridge-override-validate-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
          onyxAgentCameraBridgeStatusOverride: bridgeStatus,
          onyxAgentCameraBridgeHealthServiceOverride: bridgeService,
        ),
      );
      await tester.pumpAndSettle();
      await openAdminSystemAnchor(tester, 'LOCAL CAMERA BRIDGE');

      final validateButton = find.byKey(
        const ValueKey('admin-system-camera-bridge-validate'),
      );
      expect(validateButton, findsOneWidget);
      await tester.ensureVisible(validateButton);
      await tester.tap(validateButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-system-camera-bridge-health-result')),
        findsOneWidget,
      );
      expect(find.text('HEALTHY'), findsOneWidget);
      expect(find.text('Camera bridge health check complete.'), findsOneWidget);
      expect(find.textContaining('Validated by: OPERATOR-01'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app keeps guard voip history visible in admin audit across scopes',
    (tester) async {
      await prepareAdminRouteTest(tester);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('guards-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.guards,
        ),
      );
      await tester.pumpAndSettle();

      final stageVoipButton = find.byKey(
        const ValueKey('guards-quick-stage-voip'),
      );
      await tester.ensureVisible(stageVoipButton);
      await tester.tap(stageVoipButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stage VoIP Call'));
      await tester.pumpAndSettle();

      await pumpAdminRouteApp(tester, key: const ValueKey('admin-app'));
      await openAdminClientCommsAudit(tester);

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('LATEST VOIP STAGE'), findsOneWidget);
      expect(
        find.textContaining(
          'VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsWidgets,
      );

      await prepareAdminRouteTest(tester);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-cross-scope-guards-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.guards,
        ),
      );
      await tester.pumpAndSettle();

      final crossScopeStageVoipButton = find.byKey(
        const ValueKey('guards-quick-stage-voip'),
      );
      await tester.ensureVisible(crossScopeStageVoipButton);
      await tester.tap(crossScopeStageVoipButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stage VoIP Call'));
      await tester.pumpAndSettle();

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-cross-scope-audit-app'),
      );
      await openAdminClientCommsAudit(tester);

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Cross-scope'), findsOneWidget);
      expect(find.text('LATEST VOIP STAGE'), findsOneWidget);
      expect(
        find.textContaining(
          'VoIP staging is not configured for Thabo Mokoena yet.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app keeps admin demo-ready support and guard work surfaces deterministic',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<void> openClientDemoSuccessDialog({
        required Key appKey,
        void Function(String clientId, String siteId, String room)?
            onClientLaneRouteOpened,
      }) async {
        await tester.pumpWidget(
          OnyxApp(
            key: appKey,
            supabaseReady: false,
            initialRouteOverride: OnyxRoute.admin,
            initialAdminTabOverride: AdministrationPageTab.clients,
            onClientLaneRouteOpened: onClientLaneRouteOpened,
          ),
        );
        await tester.pumpAndSettle();

        await tapAdminDemoModeToggle(tester);
        await tester.pumpAndSettle();

        await tapAdminToolbarPrimaryAction(tester);

        await tapAdminClientDemoReady(tester);
        await tapAdminCreateReady(
          tester,
          commandDeckKey: const ValueKey('client-onboarding-command-deck'),
          createButtonKey: clientOnboardingCreateReadyButtonKey,
        );

        await waitForAdminCreateSuccessDialog(tester);
      }

      await openClientDemoSuccessDialog(
        appKey: const ValueKey('admin-client-demo-reports-app'),
      );
      final openReportsButton = find.byKey(
        const ValueKey('admin-create-success-support-open-reports-workspace'),
      );
      await tester.ensureVisible(openReportsButton);
      await tester.tap(openReportsButton);
      await tester.pumpAndSettle();

      expect(find.byType(ClientIntelligenceReportsPage), findsOneWidget);
      expect(
        tester
            .widget<ClientIntelligenceReportsPage>(
              find.byType(ClientIntelligenceReportsPage),
            )
            .selectedClient,
        startsWith('DEMO-CLT'),
      );
      expect(
        tester
            .widget<ClientIntelligenceReportsPage>(
              find.byType(ClientIntelligenceReportsPage),
            )
            .selectedSite,
        'SITE-MS-VALLEE-RESIDENCE',
      );

      await openClientDemoSuccessDialog(
        appKey: const ValueKey('admin-client-demo-governance-app'),
      );
      await tapAdminCreateSuccessSupportAction(
        tester,
        const ValueKey('admin-create-success-support-open-governance-desk'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GovernancePage), findsOneWidget);
      expect(
        tester
            .widget<GovernancePage>(find.byType(GovernancePage))
            .initialScopeClientId,
        startsWith('DEMO-CLT'),
      );
      expect(
        tester
            .widget<GovernancePage>(find.byType(GovernancePage))
            .initialScopeSiteId,
        anyOf(isNull, ''),
      );

      await openClientDemoSuccessDialog(
        appKey: const ValueKey('admin-client-demo-operations-app'),
      );
      await tapAdminCreateSuccessSupportAction(
        tester,
        const ValueKey('admin-create-success-support-open-security-desk'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiveOperationsPage), findsOneWidget);
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeClientId,
        startsWith('DEMO-CLT'),
      );
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeSiteId,
        anyOf(isNull, ''),
      );

      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;
      await openClientDemoSuccessDialog(
        appKey: const ValueKey('admin-client-demo-client-comms-app'),
        onClientLaneRouteOpened: (clientId, siteId, room) {
          openedClientId = clientId;
          openedSiteId = siteId;
          openedRoom = room;
        },
      );
      await tapAdminCreateSuccessSupportAction(
        tester,
        const ValueKey('admin-create-success-support-open-client-comms'),
      );

      expect(openedClientId, startsWith('DEMO-CLT'));
      expect(openedSiteId, '');
      expect(openedRoom, isEmpty);
      expect(find.byType(ClientsPage), findsOneWidget);
      expect(find.textContaining('Client Communications'), findsOneWidget);
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).clientId,
        startsWith('DEMO-CLT'),
      );
      expect(
        tester.widget<ClientsPage>(find.byType(ClientsPage)).siteId,
        isEmpty,
      );

      Future<void> openSiteDemoSuccessDialog({required Key appKey}) async {
        await tester.pumpWidget(
          OnyxApp(
            key: appKey,
            supabaseReady: false,
            initialRouteOverride: OnyxRoute.admin,
            initialAdminTabOverride: AdministrationPageTab.sites,
          ),
        );
        await tester.pumpAndSettle();

        await tapAdminDemoModeToggle(tester);
        await tester.pumpAndSettle();

        await tapAdminToolbarPrimaryAction(tester);

        await tapAdminSiteDemoReady(tester);
        await tapAdminCreateReady(
          tester,
          commandDeckKey: const ValueKey('site-onboarding-command-deck'),
          createButtonKey: siteOnboardingCreateReadyButtonKey,
        );

        await waitForAdminCreateSuccessDialog(tester);
      }

      await openSiteDemoSuccessDialog(
        appKey: const ValueKey('admin-site-demo-dispatch-app'),
      );
      await tapAdminCreateSuccessSupportAction(
        tester,
        const ValueKey('admin-create-success-support-open-dispatch-board'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DispatchPage), findsOneWidget);
      expect(
        tester.widget<DispatchPage>(find.byType(DispatchPage)).clientId,
        startsWith('CLT-'),
      );
      expect(
        tester.widget<DispatchPage>(find.byType(DispatchPage)).siteId,
        startsWith('DEMO-SITE-'),
      );

      await openSiteDemoSuccessDialog(
        appKey: const ValueKey('admin-site-demo-tactical-app'),
      );
      await tapAdminCreateSuccessSupportAction(
        tester,
        const ValueKey('admin-create-success-support-open-tactical-track'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TacticalPage), findsOneWidget);
      expect(
        tester
            .widget<TacticalPage>(find.byType(TacticalPage))
            .initialScopeClientId,
        startsWith('CLT-'),
      );
      expect(
        tester.widget<TacticalPage>(find.byType(TacticalPage)).initialScopeSiteId,
        startsWith('DEMO-SITE-'),
      );

      await openSiteDemoSuccessDialog(
        appKey: const ValueKey('admin-site-demo-operations-app'),
      );
      await tapAdminCreateSuccessSupportAction(
        tester,
        const ValueKey('admin-create-success-support-open-security-desk'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiveOperationsPage), findsOneWidget);
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeClientId,
        startsWith('CLT-'),
      );
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeSiteId,
        startsWith('DEMO-SITE-'),
      );

      Future<void> openEmployeeDemoSuccessDialog({required Key appKey}) async {
        await tester.pumpWidget(
          OnyxApp(
            key: appKey,
            supabaseReady: false,
            initialRouteOverride: OnyxRoute.admin,
            initialAdminTabOverride: AdministrationPageTab.guards,
          ),
        );
        await tester.pumpAndSettle();

        await tapAdminDemoModeToggle(tester);
        await tester.pumpAndSettle();

        await tapAdminToolbarPrimaryAction(tester);

        await tapAdminEmployeeDemoReady(tester);
        await tapAdminCreateReady(
          tester,
          commandDeckKey: const ValueKey('employee-onboarding-command-deck'),
          createButtonKey: employeeOnboardingCreateReadyButtonKey,
        );

        await waitForAdminCreateSuccessDialog(tester);
      }

      await openEmployeeDemoSuccessDialog(
        appKey: const ValueKey('admin-employee-demo-tactical-app'),
      );
      await tapAdminCreateSuccessSupportAction(
        tester,
        const ValueKey('admin-create-success-support-open-tactical-track'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TacticalPage), findsOneWidget);
      expect(
        tester
            .widget<TacticalPage>(find.byType(TacticalPage))
            .initialScopeClientId,
        'CLT-001',
      );
      expect(
        tester.widget<TacticalPage>(find.byType(TacticalPage)).initialScopeSiteId,
        'WTF-MAIN',
      );

      await openEmployeeDemoSuccessDialog(
        appKey: const ValueKey('admin-employee-demo-dispatch-app'),
      );
      await tapAdminCreateSuccessSupportAction(
        tester,
        const ValueKey('admin-create-success-support-open-dispatch-board'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DispatchPage), findsOneWidget);
      expect(
        tester.widget<DispatchPage>(find.byType(DispatchPage)).clientId,
        'CLT-001',
      );
      expect(
        tester.widget<DispatchPage>(find.byType(DispatchPage)).siteId,
        'WTF-MAIN',
      );

      await openEmployeeDemoSuccessDialog(
        appKey: const ValueKey('admin-employee-demo-operations-app'),
      );
      await tapAdminCreateSuccessSupportAction(
        tester,
        const ValueKey('admin-create-success-support-open-security-desk'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiveOperationsPage), findsOneWidget);
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeClientId,
        'CLT-001',
      );
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeSiteId,
        'WTF-MAIN',
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-build-demo-stack-operations-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.guards,
        ),
      );
      await tester.pumpAndSettle();

      await tapAdminDemoModeToggle(tester);
      await tester.pumpAndSettle();

      await tapAdminBuildDemoStack(tester);

      expect(find.byType(LiveOperationsPage), findsOneWidget);
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeClientId,
        startsWith('DEMO-CLT-'),
      );
      expect(
        tester
            .widget<LiveOperationsPage>(find.byType(LiveOperationsPage))
            .initialScopeSiteId,
        startsWith('DEMO-SITE-'),
      );

      await prepareAdminRouteTest(tester);

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveAdminPageTab(AdministrationPageTab.guards);
      await persistence.saveAdminWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.limited,
      );

      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-limited-watch-drilldown-restart-app'),
        initialAdminTab: AdministrationPageTab.guards,
      );

      expect(find.text('System Information'), findsOneWidget);
      expect(find.text('SLA Tiers'), findsOneWidget);
      expect(find.textContaining('Thabo Mokoena'), findsNothing);
    },
  );

  testWidgets(
    'onyx app keeps off-scope Client Comms routing and audit detail deterministic across admin surfaces',
    (tester) async {
      String? openedClientId;
      String? openedSiteId;
      String? openedRoom;

      Future<void> expectOpenedOffScopeClientComms() async {
        expect(openedClientId, 'CLIENT-MS-VALLEE');
        expect(openedSiteId, 'WTF-MAIN');
        expect(openedRoom, isEmpty);
        expect(find.textContaining('Client Communications'), findsOneWidget);
      }

      await prepareAdminRouteTest(tester);
      await seedWaterfallResidentAsk();
      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-cross-scope-live-ask-open-lane-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
          onClientLaneRouteOpened: (clientId, siteId, room) {
            openedClientId = clientId;
            openedSiteId = siteId;
            openedRoom = room;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Cross-scope'), findsWidgets);
      expect(find.text('1 live ask'), findsOneWidget);
      expect(find.text('LATEST CLIENT ASK'), findsOneWidget);
      expect(
        find.textContaining(
          'Please confirm whether the Waterfall response team has already arrived.',
        ),
        findsOneWidget,
      );
      await openAdminSystemAnchor(tester, 'LATEST CLIENT ASK');
      final askOpenClientCommsButton = find.byKey(
        adminClientCommsAuditOpenClientCommsButtonKey(
          'CLIENT-MS-VALLEE',
          'WTF-MAIN',
        ),
      );
      await tester.ensureVisible(askOpenClientCommsButton);
      await tester.tap(askOpenClientCommsButton);
      await tester.pumpAndSettle();
      await expectOpenedOffScopeClientComms();

      openedClientId = null;
      openedSiteId = null;
      openedRoom = null;

      await prepareAdminRouteTest(tester);
      await savePendingTelegramDrafts([
        telegramPendingDraftEntry(
          inboundUpdateId: 44,
          messageThreadId: 90,
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'WTF-MAIN',
          sourceText:
              'Please confirm whether the Waterfall desk is monitoring this thread yet.',
          originalDraftText:
              'Control is checking the latest Waterfall visual now and will share the next confirmed step shortly.',
          draftText:
              'Control is checking the latest Waterfall visual now and will share the next confirmed step shortly.',
          createdAtUtc: _adminDraftCreatedAtUtc(31),
        ),
      ]);
      await pumpAdminRouteApp(
        tester,
        key: const ValueKey('admin-open-off-scope-draft-lane-app'),
        onClientLaneRouteOpened: (clientId, siteId, room) {
          openedClientId = clientId;
          openedSiteId = siteId;
          openedRoom = room;
        },
      );
      await openAdminPendingDraftReview(tester);
      final draftOpenClientCommsButton = find.byKey(
        adminPendingDraftOpenClientCommsButtonKey(44),
      );
      await tester.ensureVisible(draftOpenClientCommsButton);
      await tester.tap(draftOpenClientCommsButton);
      await tester.pumpAndSettle();
      await expectOpenedOffScopeClientComms();

      openedClientId = null;
      openedSiteId = null;
      openedRoom = null;

      await prepareAdminRouteTest(tester);
      await seedWaterfallPushPressure(
        messageKey: 'waterfall-admin-push-open-lane-1',
      );
      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-open-off-scope-push-pressure-lane-app'),
        onClientLaneRouteOpened: (clientId, siteId, room) {
          openedClientId = clientId;
          openedSiteId = siteId;
          openedRoom = room;
        },
      );
      await openAdminSystemAnchor(tester, 'LATEST PUSH DETAIL');
      final pushOpenClientCommsButton = find.byKey(
        adminClientCommsAuditOpenClientCommsButtonKey(
          'CLIENT-MS-VALLEE',
          'WTF-MAIN',
        ),
      );
      await tester.ensureVisible(pushOpenClientCommsButton);
      await tester.tap(pushOpenClientCommsButton);
      await tester.pumpAndSettle();
      await expectOpenedOffScopeClientComms();

      await prepareAdminRouteTest(tester);

      await pumpClientControlSourceApp(
        tester,
        key: const ValueKey('admin-offscope-lane-reply-clients-app'),
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'WTF-MAIN',
      );

      const controlUpdateBody =
          'Waterfall control thread update: desk has logged the resident follow-up.';
      await tester.enterText(find.byType(TextField).first, controlUpdateBody);
      final sendControlUpdateButton = find.widgetWithText(
        FilledButton,
        'Log Resident Update',
      );
      await tester.ensureVisible(sendControlUpdateButton);
      await tester.tap(sendControlUpdateButton);
      await tester.pumpAndSettle();

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-offscope-lane-reply-admin-app'),
      );
      await tester.scrollUntilVisible(
        find.text('LATEST CLIENT COMMS REPLY'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Cross-scope'), findsWidgets);
      expect(find.text('LATEST CLIENT COMMS REPLY'), findsOneWidget);
      expect(find.textContaining(controlUpdateBody), findsOneWidget);

      await prepareAdminRouteTest(tester);

      await seedWaterfallPushPressure(messageKey: 'waterfall-admin-push-1');

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-offscope-push-pressure-app'),
      );

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Push FAILED'), findsWidgets);
      expect(find.text('1 push item queued'), findsWidgets);
      expect(find.text('RECENT DELIVERY HISTORY'), findsOneWidget);
      expect(
        find.textContaining('13:14 UTC • needs review • queue:1'),
        findsOneWidget,
      );
      expect(find.text('LATEST PUSH DETAIL'), findsOneWidget);
      expect(
        find.textContaining(
          'Waterfall push sync needs operator review before retry.',
        ),
        findsWidgets,
      );

      await prepareAdminRouteTest(tester);

      await seedWaterfallTelegramBlockedPushSync();

      await pumpAndOpenAdminClientCommsAudit(
        tester,
        key: const ValueKey('admin-telegram-detail-humanized-app'),
      );
      await openAdminSystemAnchor(tester, 'LATEST PUSH DETAIL');

      expect(find.text('Client Comms Audit'), findsOneWidget);
      expect(find.text('Telegram BLOCKED'), findsWidgets);
      expect(find.text('LATEST PUSH DETAIL'), findsOneWidget);
      expect(
        find.textContaining(
          'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx app keeps telegram ai draft review state deterministic across restart',
    (tester) async {
      await prepareAdminRouteTest(tester);

      for (final scenario in const <({
        ValueKey<String> appKey,
        int inboundUpdateId,
        int messageThreadId,
        String siteId,
        String sourceText,
        String draftText,
      })>[
        (
          appKey: ValueKey('admin-pending-draft-app'),
          inboundUpdateId: 42,
          messageThreadId: 88,
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          sourceText: 'Can you please tell me what is happening at the house?',
          draftText:
              'We are checking the latest position now and will send the next confirmed update shortly.',
        ),
        (
          appKey: ValueKey('admin-off-scope-pending-draft-app'),
          inboundUpdateId: 43,
          messageThreadId: 89,
          siteId: 'WTF-MAIN',
          sourceText:
              'Can you confirm whether the Waterfall team is already on site?',
          draftText:
              'We are checking the latest Waterfall position now and will send the next confirmed update shortly.',
        ),
      ]) {
        await savePendingTelegramDrafts([
          telegramPendingDraftEntry(
            inboundUpdateId: scenario.inboundUpdateId,
            messageThreadId: scenario.messageThreadId,
            clientId: 'CLIENT-MS-VALLEE',
            siteId: scenario.siteId,
            sourceText: scenario.sourceText,
            originalDraftText: scenario.draftText,
            draftText: scenario.draftText,
            createdAtUtc: _adminDraftCreatedAtUtc(30),
          ),
        ]);

        await pumpAdminRouteApp(
          tester,
          key: scenario.appKey,
        );
        await openAdminPendingDraftReview(tester);

        expect(find.byKey(adminTelegramAiAssistantPanelKey), findsOneWidget);
        expect(
          find.byKey(
            adminPendingDraftOpenClientCommsButtonKey(
              scenario.inboundUpdateId,
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(scenario.sourceText), findsOneWidget);
        expect(find.textContaining(scenario.draftText), findsOneWidget);
      }

      for (final scenario in const <({
        bool approved,
        bool fromLiveOperations,
        int inboundUpdateId,
        String draftText,
        String restartAppKey,
        String sourceAppKey,
      })>[
        (
          sourceAppKey: 'admin-reject-draft-app',
          restartAppKey: 'admin-reject-draft-restart-app',
          fromLiveOperations: false,
          approved: false,
          inboundUpdateId: 77,
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
        ),
        (
          sourceAppKey: 'admin-live-ops-reject-source-app',
          restartAppKey: 'admin-live-ops-reject-restart-app',
          fromLiveOperations: true,
          approved: false,
          inboundUpdateId: 903,
          draftText:
              'We are checking the latest patrol position now and will send the next verified update shortly.',
        ),
        (
          sourceAppKey: 'admin-approve-draft-app',
          restartAppKey: 'admin-approve-draft-restart-app',
          fromLiveOperations: false,
          approved: true,
          inboundUpdateId: 91,
          draftText:
              'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
        ),
        (
          sourceAppKey: 'admin-live-ops-approve-source-app',
          restartAppKey: 'admin-live-ops-approve-restart-app',
          fromLiveOperations: true,
          approved: true,
          inboundUpdateId: 905,
          draftText:
              'Control is checking the latest patrol position now and will share the next confirmed step shortly.',
        ),
      ]) {
        await prepareAdminRouteTest(tester);

        await savePendingTelegramDrafts([
          telegramPendingDraftEntry(
            inboundUpdateId: scenario.inboundUpdateId,
            messageThreadId: 88,
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            sourceText: 'Please update me on the patrol position.',
            originalDraftText:
                'We are checking the latest patrol position now and will send the next verified update shortly.',
            draftText: scenario.draftText,
            createdAtUtc: _adminDraftCreatedAtUtc(
              scenario.fromLiveOperations
                  ? (scenario.approved ? 50 : 48)
                  : (scenario.approved ? 32 : 31),
            ),
          ),
        ]);

        if (scenario.fromLiveOperations) {
          await pumpLiveOperationsSourceApp(
            tester,
            key: ValueKey(scenario.sourceAppKey),
            telegramBridgeServiceOverride:
                scenario.approved
                    ? const _SuccessfulTelegramBridgeStub()
                    : null,
          );
          expect(find.text('Pending ONYX Draft'), findsOneWidget);
          final actionButton =
              scenario.approved
                  ? find.widgetWithText(FilledButton, 'Approve + Send').first
                  : find.widgetWithText(OutlinedButton, 'Reject').first;
          await tester.ensureVisible(actionButton);
          await tester.tap(actionButton);
        } else {
          await pumpAdminRouteApp(
            tester,
            key: ValueKey(scenario.sourceAppKey),
            telegramBridgeServiceOverride:
                scenario.approved
                    ? const _SuccessfulTelegramBridgeStub()
                    : null,
          );
          await openAdminPendingDraftReview(tester);
          await tester.tap(
            find.widgetWithText(
              scenario.approved ? FilledButton : OutlinedButton,
              scenario.approved ? 'Approve + Send' : 'Reject',
            ),
          );
        }
        await tester.pumpAndSettle();

        if (scenario.approved) {
          await pumpAndOpenAdminClientCommsAudit(
            tester,
            key: ValueKey(scenario.restartAppKey),
          );

          expect(find.text('CLIENT ASKED'), findsNothing);
          expect(
            find.text('Please update me on the patrol position.'),
            findsNothing,
          );
          expect(find.text('Awaiting human sign-off'), findsNothing);
          expect(find.text('Learned style (1)'), findsOneWidget);
          expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
          expect(find.textContaining(scenario.draftText), findsWidgets);
        } else {
          await pumpAdminRouteApp(
            tester,
            key: ValueKey(scenario.restartAppKey),
          );

          expect(find.text('CLIENT ASKED'), findsNothing);
          expect(find.text('ONYX WILL SAY'), findsNothing);
          expect(find.text('Awaiting human sign-off'), findsNothing);
          expect(
            find.text('Please update me on the patrol position.'),
            findsNothing,
          );
          expect(find.text(scenario.draftText), findsNothing);
        }
      }
    },
  );

  testWidgets(
    'onyx app keeps admin client comms audit preference and learned style state deterministic after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<void> openAuditWithLearnedStyles({
        required Key appKey,
        required List<Map<String, Object?>> entries,
      }) async {
        await saveLearnedApprovalStyles(entries);
        await tester.pumpWidget(
          OnyxApp(
            key: appKey,
            supabaseReady: false,
            initialRouteOverride: OnyxRoute.admin,
            initialAdminTabOverride: AdministrationPageTab.system,
          ),
        );
        await tester.pumpAndSettle();
        await openAdminClientCommsAudit(tester);
      }

      const topStyle =
          'Control is checking the latest position now and will share the next confirmed step shortly.';
      const secondStyle =
          'You are not alone. Control is checking now and will keep this thread updated.';
      const thirdStyle =
          'Control is checking cameras now and will share the next confirmed camera check shortly.';

      await openAuditWithLearnedStyles(
        appKey: const ValueKey('admin-tag-learned-style-app'),
        entries: [
          learnedApprovalEntry(text: topStyle, approvalCount: 3),
          learnedApprovalEntry(text: secondStyle, approvalCount: 2),
        ],
      );

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Tag #2'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tag #2'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'Resident comfort',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save Tag'));
      await tester.pumpAndSettle();

      expect(find.text('Resident comfort'), findsOneWidget);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-tag-learned-style-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();
      await openAdminClientCommsAudit(tester);

      expect(find.text('Resident comfort'), findsOneWidget);

      await openAuditWithLearnedStyles(
        appKey: const ValueKey('admin-demote-learned-style-app'),
        entries: [
          learnedApprovalEntry(text: topStyle, approvalCount: 3),
          learnedApprovalEntry(text: secondStyle, approvalCount: 2),
        ],
      );

      expect(find.textContaining(topStyle), findsOneWidget);
      expect(find.text('NEXT LEARNED OPTIONS'), findsOneWidget);
      expect(find.textContaining('#2 $secondStyle'), findsOneWidget);

      await tapVisibleText(tester, 'Demote Top Style', first: false);
      await tester.pumpAndSettle();

      expect(find.textContaining(secondStyle), findsOneWidget);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-demote-learned-style-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();
      await openAdminClientCommsAudit(tester);

      expect(find.textContaining(secondStyle), findsOneWidget);

      await openAuditWithLearnedStyles(
        appKey: const ValueKey('admin-promote-learned-style-app'),
        entries: [
          learnedApprovalEntry(text: topStyle, approvalCount: 3),
          learnedApprovalEntry(text: secondStyle, approvalCount: 2),
          learnedApprovalEntry(text: thirdStyle, approvalCount: 1),
        ],
      );

      expect(find.textContaining(topStyle), findsOneWidget);
      expect(find.text('NEXT LEARNED OPTIONS'), findsOneWidget);
      expect(find.textContaining('#2 $secondStyle'), findsOneWidget);

      await tapVisibleText(tester, 'Promote #2', first: false);
      await tester.pumpAndSettle();

      expect(find.textContaining(secondStyle), findsWidgets);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-promote-learned-style-restart-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();
      await openAdminClientCommsAudit(tester);

      expect(find.textContaining(secondStyle), findsWidgets);

      final cases =
          <({
            String approvedDraftText,
            String auditAppKey,
            String clientAppKey,
            String clientId,
            bool directRestore,
            List<Map<String, Object?>> directRestoreEntries,
            List<String> expectedExtraTexts,
            List<DispatchEvent> initialStoreEventsOverride,
            String siteId,
          })>[
            (
              clientAppKey: 'admin-cross-surface-learn-clients-app',
              auditAppKey: 'admin-cross-surface-learn-admin-app',
              clientId: 'CLIENT-MS-VALLEE',
              directRestore: false,
              directRestoreEntries: const <Map<String, Object?>>[],
              expectedExtraTexts: const <String>[],
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              initialStoreEventsOverride: const <DispatchEvent>[],
              approvedDraftText:
                  'Control is checking the dispatch response for Resident Feed now and will share the next confirmed step shortly.',
            ),
            (
              clientAppKey: 'admin-learned-style-app',
              auditAppKey: '',
              clientId: 'CLIENT-MS-VALLEE',
              directRestore: true,
              directRestoreEntries: <Map<String, Object?>>[
                learnedApprovalEntry(
                  text:
                      'Control is checking the latest position now and will share the next confirmed step shortly.',
                  operatorTag: 'Warm reassurance',
                ),
              ],
              expectedExtraTexts: const <String>[
                'Warm reassurance',
                'Approved 1x',
              ],
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              initialStoreEventsOverride: const <DispatchEvent>[],
              approvedDraftText:
                  'Control is checking the latest position now and will share the next confirmed step shortly.',
            ),
            (
              clientAppKey: 'admin-offscope-cross-surface-learn-clients-app',
              auditAppKey: 'admin-offscope-cross-surface-learn-admin-app',
              clientId: 'CLIENT-MS-VALLEE',
              directRestore: false,
              directRestoreEntries: const <Map<String, Object?>>[],
              expectedExtraTexts: const <String>[],
              siteId: 'WTF-MAIN',
              initialStoreEventsOverride: <DispatchEvent>[
                _waterfallDispatchDecision(
                  dispatchId: 'DISP-WTF-LEARN-1',
                  occurredAt: _adminOffScopeOccurredAtUtc(41),
                ),
              ],
              approvedDraftText:
                  'Control is checking the Waterfall dispatch response for Resident Feed now and will share the next confirmed step shortly.',
            ),
          ];

      for (final scenario in cases) {
        if (scenario.directRestore) {
          SharedPreferences.setMockInitialValues({});
          await tester.binding.setSurfaceSize(const Size(1680, 1100));
          await saveLearnedApprovalStyles(scenario.directRestoreEntries);
          await tester.pumpWidget(
            OnyxApp(
              key: ValueKey(scenario.clientAppKey),
              supabaseReady: false,
              initialRouteOverride: OnyxRoute.admin,
              initialAdminTabOverride: AdministrationPageTab.system,
            ),
          );
          await tester.pumpAndSettle();
          await openAdminClientCommsAudit(tester);
        } else {
          await prepareAdminRouteTest(tester);

          await pumpClientControlSourceApp(
            tester,
            key: ValueKey(scenario.clientAppKey),
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

          await pumpAndOpenAdminClientCommsAudit(
            tester,
            key: ValueKey(scenario.auditAppKey),
          );
        }

        expect(find.text('Client Comms Audit'), findsOneWidget);
        if (scenario.siteId == 'WTF-MAIN') {
          expect(find.text('Cross-scope'), findsWidgets);
        }
        expect(find.text('Learned style (1)'), findsWidgets);
        expect(find.text('LEARNED APPROVAL STYLE'), findsWidgets);
        expect(find.textContaining(scenario.approvedDraftText), findsWidgets);
        for (final text in scenario.expectedExtraTexts) {
          expect(find.textContaining(text), findsWidgets);
        }

        if (scenario.directRestore) {
          await tester.binding.setSurfaceSize(null);
        }
      }

      SharedPreferences.setMockInitialValues({});
      LiveOperationsPage.debugResetQueueStateHintSession();
      await tester.binding.setSurfaceSize(const Size(1680, 1100));
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        LiveOperationsPage.debugResetQueueStateHintSession();
      });

      await saveLiveOperationsQueueHintState(
        seen: true,
        legacyLearnedStyles: const <String>[
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ],
      );

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey('admin-reset-live-ops-queue-hint-app'),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.admin,
          initialAdminTabOverride: AdministrationPageTab.system,
        ),
      );
      await tester.pumpAndSettle();

      await openAdminClientCommsAudit(tester);
      expect(find.byKey(adminClientCommsAuditPanelKey), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('admin-reset-live-ops-queue-hint-audit-button'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('admin-reset-live-ops-queue-hint-audit-button'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Live Ops tip will show again.'), findsOneWidget);

      await tester.pumpWidget(
        OnyxApp(
          key: const ValueKey(
            'dashboard-after-admin-reset-live-ops-queue-hint',
          ),
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dashboard,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('control-inbox-queue-hint')),
        findsOneWidget,
      );
      expect(find.text('Hide tip'), findsOneWidget);

      for (final scenario in const <({
        String adminAppKey,
        String clientAppKey,
        bool directRestore,
        bool fromLiveOperations,
        String tapLabel,
        bool seedPinnedVoice,
        bool shouldShowPinnedVoice,
      })>[
        (
          clientAppKey: 'admin-cross-surface-voice-clients-app',
          adminAppKey: 'admin-cross-surface-voice-admin-app',
          directRestore: false,
          fromLiveOperations: false,
          tapLabel: 'Reassuring',
          seedPinnedVoice: false,
          shouldShowPinnedVoice: true,
        ),
        (
          clientAppKey: 'admin-cross-surface-clear-voice-clients-app',
          adminAppKey: 'admin-cross-surface-clear-voice-admin-app',
          directRestore: false,
          fromLiveOperations: false,
          tapLabel: 'Auto',
          seedPinnedVoice: true,
          shouldShowPinnedVoice: false,
        ),
        (
          clientAppKey: 'admin-live-ops-voice-source-app',
          adminAppKey: 'admin-live-ops-voice-restart-app',
          directRestore: false,
          fromLiveOperations: true,
          tapLabel: 'Reassuring',
          seedPinnedVoice: false,
          shouldShowPinnedVoice: true,
        ),
        (
          clientAppKey: 'admin-voice-app',
          adminAppKey: '',
          directRestore: true,
          fromLiveOperations: false,
          tapLabel: '',
          seedPinnedVoice: true,
          shouldShowPinnedVoice: true,
        ),
      ]) {
        if (scenario.directRestore) {
          SharedPreferences.setMockInitialValues({});
          await tester.binding.setSurfaceSize(const Size(1680, 1100));
          await savePinnedLaneVoice(profile: 'reassurance-forward');
          await tester.pumpWidget(
            OnyxApp(
              key: ValueKey(scenario.clientAppKey),
              supabaseReady: false,
              initialRouteOverride: OnyxRoute.admin,
              initialAdminTabOverride: AdministrationPageTab.system,
            ),
          );
          await tester.pumpAndSettle();
          await openAdminClientCommsAudit(tester);
        } else {
          await prepareAdminRouteTest(tester);

          if (scenario.seedPinnedVoice) {
            await savePinnedLaneVoice(profile: 'reassurance-forward');
          }

          if (scenario.fromLiveOperations) {
            await pumpLiveOperationsSourceApp(
              tester,
              key: ValueKey(scenario.clientAppKey),
            );
          } else {
            await pumpClientControlSourceApp(
              tester,
              key: ValueKey(scenario.clientAppKey),
            );
          }

          final voiceControl =
              scenario.fromLiveOperations
                  ? find.widgetWithText(OutlinedButton, scenario.tapLabel)
                  : find.widgetWithText(ChoiceChip, scenario.tapLabel);
          await tester.ensureVisible(voiceControl.first);
          await tester.tap(voiceControl.first);
          await tester.pumpAndSettle();

          await pumpAndOpenAdminClientCommsAudit(
            tester,
            key: ValueKey(scenario.adminAppKey),
          );
        }

        if (scenario.shouldShowPinnedVoice) {
          expect(find.textContaining('Voice Reassuring'), findsOneWidget);
          expect(find.text('Client voice: Reassuring'), findsOneWidget);
          expect(find.text('Voice-adjusted'), findsOneWidget);
        } else {
          expect(find.textContaining('Voice Reassuring'), findsNothing);
          expect(find.text('Client voice: Reassuring'), findsNothing);
          expect(find.text('Voice-adjusted'), findsNothing);
        }

        if (scenario.directRestore) {
          await tester.binding.setSurfaceSize(null);
        }
      }

      for (final scenario in const <({
        String adminAppKey,
        bool fromLiveOperations,
        String sourceAppKey,
      })>[
        (
          sourceAppKey: 'admin-cross-surface-clear-learned-clients-app',
          adminAppKey: 'admin-cross-surface-clear-learned-admin-app',
          fromLiveOperations: false,
        ),
        (
          sourceAppKey: 'admin-live-ops-clear-learned-source-app',
          adminAppKey: 'admin-live-ops-clear-learned-restart-app',
          fromLiveOperations: true,
        ),
      ]) {
        await prepareAdminRouteTest(tester);

        await saveLegacyLearnedApprovalStyles(const <String>[
          'Control is checking the latest position now and will share the next confirmed step shortly.',
        ]);

        if (scenario.fromLiveOperations) {
          await pumpLiveOperationsSourceApp(
            tester,
            key: ValueKey(scenario.sourceAppKey),
          );
        } else {
          await pumpClientControlSourceApp(
            tester,
            key: ValueKey(scenario.sourceAppKey),
          );
        }

        final clearLearnedStyleButton = find.widgetWithText(
          OutlinedButton,
          'Clear Learned Style',
        );
        await tester.ensureVisible(clearLearnedStyleButton.first);
        await tester.tap(clearLearnedStyleButton.first);
        await tester.pumpAndSettle();

        await pumpAndOpenAdminClientCommsAudit(
          tester,
          key: ValueKey(scenario.adminAppKey),
        );

        expect(find.text('Learned style (1)'), findsNothing);
        expect(find.text('LEARNED APPROVAL STYLE'), findsNothing);
        expect(find.text('ONYX using learned style'), findsNothing);
      }
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
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'WTF-MAIN',
  );
}
