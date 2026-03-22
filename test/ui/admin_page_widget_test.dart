import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/application/monitoring_identity_policy_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/site_identity_registry_repository.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_advisory_recorded.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_feed_cycle_recorded.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_parity_cycle_recorded.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const liveOpsTipResetDraftButtonKey = ValueKey(
    'admin-reset-live-ops-queue-hint-draft-button',
  );
  const liveOpsTipResetAuditButtonKey = ValueKey(
    'admin-reset-live-ops-queue-hint-audit-button',
  );
  const adminExportDataButtonKey = ValueKey('admin-export-data-button');
  const adminImportCsvButtonKey = ValueKey('admin-import-csv-button');
  const liveOpsTipResetNote =
      'Live Ops tip only. This re-enables the queue onboarding hint in live operations and does not change Telegram voice settings.';
  const liveOpsTipResetSuccessSnack = 'Live Ops tip will show again.';
  const liveOpsTipResetFailureSnack = 'Failed to re-enable Live Ops tip.';

  List<String> profileButtonLabels(WidgetTester tester) {
    const profileLabels = <String>{
      'Auto',
      'Concise',
      'Reassuring',
      'Validation-heavy',
    };
    return tester
        .widgetList<OutlinedButton>(find.byType(OutlinedButton))
        .map((button) => button.child)
        .whereType<Text>()
        .map((text) => text.data ?? '')
        .where(profileLabels.contains)
        .toList(growable: false);
  }

  void expectOutlinedButtonEnabled(
    WidgetTester tester,
    String label, {
    int index = 0,
  }) {
    final button = tester
        .widgetList<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
        .elementAt(index);
    expect(button.onPressed, isNotNull, reason: '$label should be enabled');
  }

  void expectOutlinedButtonDisabled(
    WidgetTester tester,
    String label, {
    int index = 0,
  }) {
    final button = tester
        .widgetList<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
        .elementAt(index);
    expect(button.onPressed, isNull, reason: '$label should be disabled');
  }

  void expectFilledButtonEnabled(
    WidgetTester tester,
    String label, {
    int index = 0,
  }) {
    final button = tester
        .widgetList<FilledButton>(find.widgetWithText(FilledButton, label))
        .elementAt(index);
    expect(button.onPressed, isNotNull, reason: '$label should be enabled');
  }

  Finder liveOpsTipResetButtonFinder({required bool audit}) {
    return find.byKey(
      audit ? liveOpsTipResetAuditButtonKey : liveOpsTipResetDraftButtonKey,
    );
  }

  void expectLiveOpsTipResetButtonSurface(
    WidgetTester tester, {
    required bool audit,
  }) {
    expect(liveOpsTipResetButtonFinder(audit: audit), findsOneWidget);
    expect(liveOpsTipResetButtonFinder(audit: !audit), findsNothing);
  }

  Future<void> tapLiveOpsTipResetButton(
    WidgetTester tester, {
    required bool audit,
  }) async {
    final finder = liveOpsTipResetButtonFinder(audit: audit);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
  }

  Future<void> tapVisibleText(
    WidgetTester tester,
    String text, {
    bool first = true,
  }) async {
    final resolvedText = switch (text) {
      'System' => 'SYSTEM CONTROLS',
      _ => text,
    };
    final finder = first
        ? find.text(resolvedText).first
        : find.text(resolvedText).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
  }

  TelegramAiPendingDraftView buildLiveOpsTipResetDraftView({
    required int updateId,
    required DateTime createdAtUtc,
  }) {
    return TelegramAiPendingDraftView(
      updateId: updateId,
      audience: 'client',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      chatId: '123456',
      sourceText: 'Any update?',
      draftText:
          'Control is checking now and will share the next confirmed step shortly.',
      providerLabel: 'openai:gpt-4.1-mini',
      learnedRewriteCount: 1,
      learnedRewriteExample:
          'Control is checking now and will share the next confirmed step shortly.',
      learnedRewritePreviews: const [
        TelegramAiLearnedStylePreviewView(
          text:
              'Control is checking now and will share the next confirmed step shortly.',
          approvalCount: 2,
        ),
      ],
      createdAtUtc: createdAtUtc,
    );
  }

  ClientCommsAuditView buildLiveOpsTipResetAuditView(DateTime nowUtc) {
    return ClientCommsAuditView(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      matchesSelectedScope: true,
      pendingApprovalCount: 1,
      pendingLearnedStyleDraftCount: 1,
      learnedApprovalStyleCount: 1,
      learnedApprovalStyleExample:
          'Control is checking now and will share the next confirmed step shortly.',
      learnedApprovalStyleApprovalCount: 2,
      learnedApprovalStyleLastUsedAtUtc: nowUtc.subtract(
        const Duration(minutes: 45),
      ),
      learnedApprovalStylePreviews: [
        TelegramAiLearnedStylePreviewView(
          text:
              'Control is checking now and will share the next confirmed step shortly.',
          approvalCount: 2,
          lastUsedAtUtc: nowUtc.subtract(const Duration(minutes: 45)),
        ),
      ],
    );
  }

  Future<void> pumpAdminWithLiveOpsTipResetDraft(
    WidgetTester tester, {
    required int updateId,
    required DateTime createdAtUtc,
    required Future<void> Function() onReset,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          telegramAiPendingDrafts: <TelegramAiPendingDraftView>[
            buildLiveOpsTipResetDraftView(
              updateId: updateId,
              createdAtUtc: createdAtUtc,
            ),
          ],
          onResetLiveOperationsQueueHint: onReset,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpAdminWithLiveOpsTipResetAudit(
    WidgetTester tester, {
    required DateTime nowUtc,
    required Future<void> Function() onReset,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          clientCommsAuditViews: <ClientCommsAuditView>[
            buildLiveOpsTipResetAuditView(nowUtc),
          ],
          onResetLiveOperationsQueueHint: onReset,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('administration page stays stable on phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('ENTITY MANAGEMENT'), findsWidgets);
    expect(find.text('Guards'), findsWidgets);
    expect(find.text('Sites'), findsWidgets);
    expect(find.text('Clients'), findsWidgets);
    expect(find.byKey(adminExportDataButtonKey), findsOneWidget);
    expect(find.byKey(adminImportCsvButtonKey), findsOneWidget);
    expectOutlinedButtonEnabled(tester, 'Export Data');
    expectFilledButtonEnabled(tester, 'Import CSV');
    expect(tester.takeException(), isNull);
  });

  testWidgets('administration page exports active directory data', (
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

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(adminExportDataButtonKey));
    await tester.pumpAndSettle();

    expect(copiedPayload, contains('employee_code,name,role'));
    expect(copiedPayload, contains('EMP-441,Thabo Mokoena'));
    expect(find.text('Employee CSV copied.'), findsOneWidget);
  });

  testWidgets('administration page imports CSV into the active directory tab', (
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

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(adminImportCsvButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'employee_code,name,role,assigned_site,phone,email,psira_number,status\n'
      'GRD-777,Aphiwe Dlamini,guard,SDN-NORTH,+27 82 000 7777,aphiwe@onyx.local,PSI-777-2026,active',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.text('Imported 1 employee from CSV.'), findsOneWidget);

    await tester.tap(find.byKey(adminExportDataButtonKey));
    await tester.pumpAndSettle();

    expect(copiedPayload, contains('GRD-777,Aphiwe Dlamini'));
  });

  testWidgets('administration page stays stable on landscape viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('ENTITY MANAGEMENT'), findsWidgets);
    expect(find.text('Guards'), findsWidgets);
    expect(find.text('Clients'), findsWidgets);
    expect(find.text('Sites'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administration page renders desktop workspace rail pivots', (
    tester,
  ) async {
    String? copiedPayload;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedPayload =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-workspace-panel-rail')),
      findsOneWidget,
    );
    expect(find.text('Command Rail'), findsOneWidget);
    expect(find.text('COMMAND FOCUS'), findsOneWidget);
    expect(find.text('Seed Source: Local'), findsWidgets);
    expect(find.text('Route Posture: Standby'), findsOneWidget);
    expect(find.text('Search guard roster...'), findsOneWidget);
    expect(
      find.textContaining(
        'live boards, control scopes, and desktop command tools',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Roster controls, search pivots, and create commands stay pinned',
      ),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('admin-workspace-panel-active')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-workspace-status-banner')),
      findsOneWidget,
    );
    expect(find.text('Current Focus: Guards'), findsOneWidget);
    expect(find.text('11 Directory Footprint'), findsOneWidget);
    expect(find.text('0 AI Drafts Queued'), findsOneWidget);
    expect(find.text('0 Client Audits Queued'), findsOneWidget);
    expect(find.text('0 Identity Intakes Queued'), findsOneWidget);
    expect(find.text('0 Recovery Scopes Queued'), findsOneWidget);
    expect(find.text('Bridge Pulse: idle'), findsOneWidget);
    expect(find.text('Command Operator: OPERATOR-01'), findsOneWidget);
    expect(find.text('Open Employee Onboarding'), findsOneWidget);
    expect(find.text('Directory Board'), findsWidgets);
    expect(find.text('AI Queue'), findsWidgets);
    expect(find.text('COMMAND TOOLS'), findsOneWidget);
    expect(find.text('Export Directory Snapshot'), findsOneWidget);
    expect(find.text('Import Directory CSV'), findsOneWidget);
    expect(find.text('BOARD PIVOTS'), findsOneWidget);
    expect(find.text('Control Board'), findsWidgets);
    expect(find.text('Watch Identity'), findsWidgets);
    expect(find.text('AI Draft Queue'), findsOneWidget);
    expect(find.text('Identity Intake Queue'), findsOneWidget);
    expect(find.text('Recovery Scope Queue'), findsOneWidget);
    expect(find.text('Client Audit Queue'), findsOneWidget);
    expect(
      find.textContaining('stay visible in the Context Deck'),
      findsOneWidget,
    );
    expect(find.text('CONTEXT SNAPSHOT'), findsOneWidget);
    expect(find.text('COMMAND PIVOTS'), findsOneWidget);
    expect(find.text('Open Guard Roster'), findsOneWidget);
    expect(find.text('Open Site Footprint'), findsOneWidget);
    expect(find.text('Open AI Queue'), findsOneWidget);
    expect(
      find.textContaining('roster command work and directory review'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-workspace-panel-context')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'queue pressure, and the next command pivots visible',
      ),
      findsOneWidget,
    );
    expect(find.text('Context Deck'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-workspace-export-directory')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-workspace-import-directory')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-workspace-export-directory')),
    );
    await tester.tap(
      find.byKey(const ValueKey('admin-workspace-export-directory')),
    );
    await tester.pump();
    expect(copiedPayload, contains('employee_code,name,role'));
    expect(find.text('Employee CSV copied.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    final aiCommsAction = tester.widget<InkWell>(
      find.byKey(const ValueKey('admin-workspace-banner-open-ai-comms')),
    );
    expect(aiCommsAction.onTap, isNotNull);
    aiCommsAction.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('LEARNED APPROVAL STYLES'), findsOneWidget);
    expect(find.text('PENDING AI DRAFT REVIEW'), findsOneWidget);

    final watchIdentityAction = tester.widget<InkWell>(
      find.byKey(const ValueKey('admin-workspace-banner-open-watch-identity')),
    );
    expect(watchIdentityAction.onTap, isNotNull);
    watchIdentityAction.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('WATCH & IDENTITY CONTROLS'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-workspace-context-open-guards')),
    );
    await tester.tap(
      find.byKey(const ValueKey('admin-workspace-context-open-guards')),
    );
    await tester.pumpAndSettle();
    expect(find.text('DIRECTORY WORKSPACE'), findsOneWidget);
    expect(find.textContaining('Thabo Mokoena'), findsOneWidget);
  });

  testWidgets('administration page switches tabs and shows system cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Thabo Mokoena'), findsOneWidget);

    await tester.ensureVisible(find.text('SYSTEM CONTROLS').first);
    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('SLA Tiers'));
    expect(find.text('SLA Tiers'), findsOneWidget);
    expect(find.text('Risk Policies'), findsOneWidget);
    expect(find.text('SYSTEM RUNTIME CONTROLS'), findsOneWidget);
  });

  testWidgets('administration page can start on system tab from parent state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SYSTEM RUNTIME CONTROLS'), findsOneWidget);
    expect(find.text('SLA Tiers'), findsOneWidget);
    expect(find.textContaining('Thabo Mokoena'), findsNothing);
  });

  testWidgets(
    'system runtime command deck focuses radio runtime and ops health',
    (tester) async {
      var resetCalls = 0;
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            radioOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:00 UTC',
            radioOpsQueueHealth:
                'pending 2 • due 1 • deferred 1 • max-attempt 2',
            radioOpsFailureDetail:
                'Last failure • ZEL-9001 • reason send_failed • count 2 • at 10:05:30 UTC',
            onResetLiveOperationsQueueHint: () async {
              resetCalls += 1;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-system-runtime-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-system-runtime-next-move')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-system-runtime-open-radio')),
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-system-runtime-open-radio')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-radio-intent-command')),
        findsOneWidget,
      );
      expect(find.text('Focused radio runtime controls.'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-system-runtime-open-ops')),
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-system-runtime-open-ops')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-ops-poll-command')),
        findsOneWidget,
      );
      expect(find.text('Focused ops poll health.'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-system-runtime-reset-queue-hint')),
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-system-runtime-reset-queue-hint')),
      );
      await tester.pumpAndSettle();

      expect(resetCalls, 1);
      expect(find.text('Live Ops tip will show again.'), findsOneWidget);
    },
  );

  testWidgets('system sla and policy command decks expose anchored pivots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-sla-command')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-policy-command')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-sla-tier-bronze')),
    );
    await tester.tap(find.byKey(const ValueKey('admin-sla-tier-bronze')));
    await tester.pumpAndSettle();
    expect(find.text('Selected Bronze SLA focus.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-sla-open-readiness')),
    );
    await tester.tap(find.byKey(const ValueKey('admin-sla-open-readiness')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-global-readiness-card')),
      findsOneWidget,
    );
    expect(
      find.text('Focused global readiness for Bronze SLA.'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-policy-row-guard-heartbeat')),
    );
    await tester.tap(
      find.byKey(const ValueKey('admin-policy-row-guard-heartbeat')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Selected Guard heartbeat interval policy focus.'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-policy-open-listener')),
    );
    await tester.tap(find.byKey(const ValueKey('admin-policy-open-listener')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-listener-alarm-command')),
      findsOneWidget,
    );
    expect(
      find.text('Focused listener alarm for Guard heartbeat interval.'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-policy-open-runtime')),
    );
    await tester.tap(find.byKey(const ValueKey('admin-policy-open-runtime')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-system-runtime-command')),
      findsOneWidget,
    );
    expect(
      find.text('Focused runtime command for Guard heartbeat interval.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'demo storyboard command deck copies the runbook into the desktop receipt',
    (tester) async {
      String? copiedPayload;
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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

      await tester.pumpWidget(
        const MaterialApp(
          home: AdministrationPage(
            events: <DispatchEvent>[],
            supabaseReady: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-demo-storyboard-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-demo-storyboard-next-move')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-demo-storyboard-primary-action')),
        findsOneWidget,
      );
      expect(find.text('Demo Mode: ON'), findsOneWidget);
      expect(find.text('Bridge Status: Disabled'), findsWidgets);
      expect(find.text('Route Scenario: Industrial'), findsOneWidget);
      expect(find.text('Seed Source: Local'), findsWidgets);

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-demo-storyboard-copy-runbook')),
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-demo-storyboard-copy-runbook')),
      );
      await tester.pumpAndSettle();

      expect(copiedPayload, contains('ONYX Client Demo Runbook'));
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text('RUNBOOK HANDOFF'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text('Storyboard runbook copied for command review.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(
            'The storyboard keeps the seeded runbook pinned in the desktop command rail while you continue routing through the live demo path.',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('system workspace launch flow routes into client onboarding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-workspace-launch-system-flow')),
    );
    await tester.tap(
      find.byKey(const ValueKey('admin-workspace-launch-system-flow')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-system-launch-flow-dialog')),
      findsOneWidget,
    );
    expect(find.text('Launch Admin Flow'), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('admin-system-launch-flow-client')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-system-launch-flow-dialog')),
      findsNothing,
    );
    expect(find.text('New Client Onboarding'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('system tab can update operator runtime in app', (tester) async {
    String operatorId = 'OPS-ALPHA';
    final savedOperatorIds = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              initialTab: AdministrationPageTab.system,
              operatorId: operatorId,
              onSetOperatorId: (value) async {
                savedOperatorIds.add(value);
                setState(() {
                  operatorId = value.trim().isEmpty
                      ? 'OPERATOR-01'
                      : value.trim();
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operator Runtime'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-operator-runtime-command')),
      findsOneWidget,
    );
    expect(find.text('Active operator: OPS-ALPHA'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('admin-operator-runtime-field')),
      'OPS-BETA',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-operator-runtime-apply-command')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-operator-runtime-next-move')),
        matching: find.text('Apply runtime'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('admin-operator-runtime-apply-command')),
    );
    await tester.pumpAndSettle();

    expect(savedOperatorIds, <String>['OPS-BETA']);
    expect(find.text('Active operator: OPS-BETA'), findsOneWidget);
    expect(find.text('Operator runtime set to OPS-BETA.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-operator-runtime-reset-command')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-operator-runtime-reset-command')),
    );
    await tester.pumpAndSettle();

    expect(savedOperatorIds, <String>['OPS-BETA', '']);
    expect(find.text('Active operator: OPERATOR-01'), findsOneWidget);
  });

  testWidgets('system tab can manage partner dispatch runtime lane', (
    tester,
  ) async {
    late Map<String, Object?> boundPayload;
    late Map<String, Object?> checkedPayload;
    late Map<String, Object?> unlinkedPayload;

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          onBindPartnerTelegramEndpoint:
              ({
                required clientId,
                required siteId,
                required endpointLabel,
                required chatId,
                int? threadId,
              }) async {
                boundPayload = <String, Object?>{
                  'clientId': clientId,
                  'siteId': siteId,
                  'endpointLabel': endpointLabel,
                  'chatId': chatId,
                  'threadId': threadId,
                };
                return 'PASS (partner lane bound)\nscope=$clientId/$siteId';
              },
          onCheckPartnerTelegramEndpoint:
              ({
                required clientId,
                required siteId,
                required chatId,
                int? threadId,
              }) async {
                checkedPayload = <String, Object?>{
                  'clientId': clientId,
                  'siteId': siteId,
                  'chatId': chatId,
                  'threadId': threadId,
                };
                return 'PASS (partner lane linked)\nscope=$clientId/$siteId';
              },
          onUnlinkPartnerTelegramEndpoint:
              ({
                required clientId,
                required siteId,
                required chatId,
                int? threadId,
              }) async {
                unlinkedPayload = <String, Object?>{
                  'clientId': clientId,
                  'siteId': siteId,
                  'chatId': chatId,
                  'threadId': threadId,
                };
                return 'PASS (partner lane updated)\nscope=$clientId/$siteId';
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Dispatch Runtime'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-partner-runtime-command')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('admin-partner-runtime-label-field')),
      'Field Response',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-partner-runtime-chat-field')),
      '-1001234567890',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-partner-runtime-thread-field')),
      '77',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-partner-runtime-bind-command')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-partner-runtime-bind-command')),
    );
    await tester.pumpAndSettle();

    expect(boundPayload['clientId'], 'CLT-001');
    expect(boundPayload['siteId'], 'WTF-MAIN');
    expect(boundPayload['endpointLabel'], 'Field Response');
    expect(boundPayload['chatId'], '-1001234567890');
    expect(boundPayload['threadId'], 77);
    expect(find.textContaining('PASS (partner lane bound)'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-partner-runtime-check-command')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-partner-runtime-check-command')),
    );
    await tester.pumpAndSettle();

    expect(checkedPayload['clientId'], 'CLT-001');
    expect(checkedPayload['siteId'], 'WTF-MAIN');
    expect(checkedPayload['chatId'], '-1001234567890');
    expect(checkedPayload['threadId'], 77);
    expect(find.textContaining('PASS (partner lane linked)'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-partner-runtime-unlink-command')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-partner-runtime-unlink-command')),
    );
    await tester.pumpAndSettle();

    expect(unlinkedPayload['clientId'], 'CLT-001');
    expect(unlinkedPayload['siteId'], 'WTF-MAIN');
    expect(unlinkedPayload['chatId'], '-1001234567890');
    expect(unlinkedPayload['threadId'], 77);
    expect(find.textContaining('PASS (partner lane updated)'), findsOneWidget);
  });

  testWidgets('system tab shows partner scorecard summary and opens scope drill-in', (
    tester,
  ) async {
    String? copiedPayload;
    var openedGovernance = 0;
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

    final priorReport = SovereignReport(
      date: '2026-03-14',
      generatedAtUtc: DateTime.utc(2026, 3, 14, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 13, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 14, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 10,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 1,
        humanOverrides: 0,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 1,
        driftDetected: 0,
        avgMatchScore: 100,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 1,
        declarationCount: 1,
        acceptedCount: 1,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 1,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLT-001',
            siteId: 'WTF-MAIN',
            partnerLabel: 'PARTNER • Alpha',
            dispatchCount: 1,
            strongCount: 0,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 1,
            averageAcceptedDelayMinutes: 12.0,
            averageOnSiteDelayMinutes: 22.0,
            summaryLine:
                'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
          ),
        ],
      ),
    );
    final currentReport = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: DateTime.utc(2026, 3, 15, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 14, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 15, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 12,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 1,
        humanOverrides: 0,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 1,
        driftDetected: 0,
        avgMatchScore: 100,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 1,
        declarationCount: 3,
        acceptedCount: 1,
        onSiteCount: 1,
        allClearCount: 1,
        cancelledCount: 0,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLT-001',
            siteId: 'WTF-MAIN',
            partnerLabel: 'PARTNER • Alpha',
            dispatchCount: 1,
            strongCount: 1,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 4.0,
            averageOnSiteDelayMinutes: 10.0,
            summaryLine:
                'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          morningSovereignReportHistory: [priorReport, currentReport],
          onOpenGovernance: () {
            openedGovernance += 1;
          },
          initialSitePartnerLaneDetails: const <String, List<String>>{
            'CLT-001::WTF-MAIN': <String>[
              'PARTNER • Alpha • chat=-1001234567890 • thread=77',
            ],
          },
          initialSitePartnerChatcheckStatus: const <String, String>{
            'CLT-001::WTF-MAIN': 'PASS (partner lane linked)',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-partner-scorecard-card')),
      findsOneWidget,
    );
    expect(find.text('Slipping: 0'), findsOneWidget);
    expect(find.text('Critical: 0'), findsWidgets);
    expect(find.text('Improving: 1'), findsOneWidget);
    expect(find.text('Open Governance'), findsOneWidget);
    expect(find.text('Copy Scorecard JSON'), findsOneWidget);
    expect(find.text('Copy Scorecard CSV'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Governance'));
    await tester.tap(find.text('Open Governance'));
    await tester.pumpAndSettle();

    expect(openedGovernance, 1);
    expect(find.text('Opening Governance for scope: WTF-MAIN'), findsOneWidget);

    await tester.tap(find.text('Copy Scorecard JSON'));
    await tester.pumpAndSettle();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('"scorecardRows"'));
    expect(copiedPayload, contains('"clientId": "CLT-001"'));
    expect(copiedPayload, contains('"siteId": "WTF-MAIN"'));
    expect(copiedPayload, contains('"partnerLabel": "PARTNER • Alpha"'));
    expect(copiedPayload, contains('"trendLabel": "IMPROVING"'));

    await tester.ensureVisible(find.text('Copy Scorecard CSV'));
    await tester.tap(find.text('Copy Scorecard CSV'));
    await tester.pumpAndSettle();

    expect(copiedPayload, isNotNull);
    expect(
      copiedPayload,
      contains(
        'client_id,site_id,partner_label,report_days,dispatch_count,strong_count',
      ),
    );
    expect(copiedPayload, contains('"CLT-001","WTF-MAIN","PARTNER • Alpha"'));
    expect(copiedPayload, contains('"IMPROVING"'));

    final scorecardFinder = find.byKey(
      const ValueKey(
        'admin-partner-scorecard-CLT-001-WTF-MAIN-PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(scorecardFinder);
    await tester.tap(scorecardFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('Partner Dispatch Detail'), findsOneWidget);
    expect(find.text('7-day trend'), findsOneWidget);
    expect(
      find.text('Acceptance timing improved against the prior 7-day average.'),
      findsWidgets,
    );
    expect(
      find.text('PARTNER • Alpha • chat=-1001234567890 • thread=77'),
      findsOneWidget,
    );
  });

  testWidgets('system tab partner scorecard prefers scoped governance', (
    tester,
  ) async {
    String? openedClientId;
    String? openedSiteId;

    final currentReport = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: DateTime.utc(2026, 3, 15, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 14, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 15, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 12,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 1,
        humanOverrides: 0,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 1,
        driftDetected: 0,
        avgMatchScore: 100,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      partnerProgression: const SovereignReportPartnerProgression(
        dispatchCount: 1,
        declarationCount: 3,
        acceptedCount: 1,
        onSiteCount: 1,
        allClearCount: 1,
        cancelledCount: 0,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLT-001',
            siteId: 'WTF-MAIN',
            partnerLabel: 'PARTNER • Alpha',
            dispatchCount: 1,
            strongCount: 1,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 4.0,
            averageOnSiteDelayMinutes: 10.0,
            summaryLine:
                'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          morningSovereignReportHistory: [currentReport],
          onOpenGovernanceForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-partner-scorecard-card')),
      findsOneWidget,
    );
    expect(find.text('Open Governance'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Governance'));
    await tester.tap(find.text('Open Governance'));
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLT-001');
    expect(openedSiteId, 'WTF-MAIN');
    expect(find.text('Opening Governance for scope: WTF-MAIN'), findsOneWidget);
  });

  testWidgets('admin tables surface partner lane health summaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.clients,
          initialClientPartnerEndpointCounts: <String, int>{'CLT-001': 2},
          initialClientPartnerLanePreview: <String, String>{
            'CLT-001': 'PARTNER • Alpha • PARTNER • Bravo',
          },
          initialClientPartnerChatcheckStatus: <String, String>{
            'CLT-001': 'PASS (partner lane linked)',
          },
          initialSitePartnerEndpointCounts: <String, int>{
            'CLT-001::WTF-MAIN': 1,
          },
          initialSitePartnerChatcheckStatus: <String, String>{
            'CLT-001::WTF-MAIN': 'FAIL (partner lane missing)',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, 'Link Chat Bridge'),
      findsOneWidget,
    );
    expect(
      find.text('Command Contact: David Wilson • +27 11 888 0001'),
      findsOneWidget,
    );
    expect(
      find.text('Service Window: 2024-01-01 to 2026-12-31'),
      findsOneWidget,
    );
    expect(find.text('Partner Network: 2'), findsOneWidget);
    expect(
      find.text('Partner Routes: PARTNER • Alpha • PARTNER • Bravo'),
      findsOneWidget,
    );
    expect(
      find.text('Partner Health: PASS (partner lane linked)'),
      findsOneWidget,
    );
    expect(find.text('PARTNER PASS'), findsOneWidget);

    await tapVisibleText(tester, 'Sites');
    await tester.pumpAndSettle();

    expect(find.text('Partner Network: 1'), findsOneWidget);
    expect(
      find.text('Partner Health: FAIL (partner lane missing)'),
      findsOneWidget,
    );
    expect(find.text('PARTNER FAIL'), findsOneWidget);
  });

  testWidgets(
    'client chat lane bridge keeps link wording across dialog actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AdministrationPage(
            events: <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.clients,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clientLaneEditButton = find.byKey(
        const ValueKey('admin-edit-client-CLT-001'),
      );
      await tester.ensureVisible(clientLaneEditButton);
      await tester.tap(clientLaneEditButton);
      await tester.pumpAndSettle();

      expect(find.text('Link Client Chat Lane'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Link All Site Lanes'),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.text('Apply to all current client sites'),
      );
      await tester.tap(find.text('Apply to all current client sites'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Link Chat Lane'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'client onboarding preview opens scoped operations and tactical lanes',
    (tester) async {
      String? openedOperationsClientId;
      String? openedOperationsSiteId;
      String? openedTacticalClientId;
      String? openedTacticalSiteId;
      String? openedTacticalIncidentReference;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.clients,
            onOpenOperationsForScope: (clientId, siteId) {
              openedOperationsClientId = clientId;
              openedOperationsSiteId = siteId;
            },
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
              openedTacticalClientId = clientId;
              openedTacticalSiteId = siteId;
              openedTacticalIncidentReference = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tester.ensureVisible(find.text('Demo Mode'));
      await tester.ensureVisible(find.text('Demo Mode'));
      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Client ID (e.g. CLIENT-001)'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-command-deck')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-next-move')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-preview-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-preview-handoff-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-preview-snapshot-band')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-preview-command-context')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('client-onboarding-preview-next-move-detail'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('client-onboarding-preview-command-support-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-preview-progress-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('client-onboarding-preview-readiness-command'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-preview-readiness-gates')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('client-onboarding-preview-highlights-command'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('client-onboarding-preview-highlights-spotlight'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('client-onboarding-preview-handoff-support-tools'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-flow-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-coach-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step-title-0')),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('onboarding-step-title-status-0')),
          matching: find.text('LIVE'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('client-onboarding-step-panel-identity-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-field-client-id-shell')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('onboarding-field-client-id-status')),
          matching: find.text('TEXT LIVE'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Client ID (e.g. CLIENT-001)'),
        'CLIENT-VALLEE',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Legal Entity Name'),
        'MS Vallee Residence',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Open Operations'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Operations'));
      await tester.pumpAndSettle();

      expect(openedOperationsClientId, 'CLIENT-VALLEE');
      expect(openedOperationsSiteId, '');

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Client ID (e.g. CLIENT-001)'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Client ID (e.g. CLIENT-001)'),
        'CLIENT-VALLEE',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Legal Entity Name'),
        'MS Vallee Residence',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Open Tactical'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Tactical'));
      await tester.pumpAndSettle();

      expect(openedTacticalClientId, 'CLIENT-VALLEE');
      expect(openedTacticalSiteId, '');
      expect(openedTacticalIncidentReference, isNull);
    },
  );

  testWidgets(
    'client onboarding preview buttons stay disabled until routeable identity is present',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.clients,
            onOpenOperationsForScope: (clientId, siteId) {},
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {},
            onOpenOperationsForIncident: (reference) {},
            onOpenTacticalForIncident: (reference) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-onboarding-primary-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-workflow-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-workflow-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-workflow-next-move')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-workflow-support-tools')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-flow-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-coach-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-ops-focus')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-tactical-focus')),
        findsNothing,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Client ID (e.g. CLIENT-001)'),
        'CLIENT-VALLEE',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-onboarding-ops-focus')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-tactical-focus')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'client onboarding preview pins dialog and admin receipts for copy snapshot',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? copiedSnapshot;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedSnapshot = args['text'] as String?;
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

      await tester.pumpWidget(
        const MaterialApp(
          home: AdministrationPage(
            events: <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.clients,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final copySnapshotButton = find.widgetWithText(
        OutlinedButton,
        'Copy Snapshot',
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-command-deck')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-workflow-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-preview-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-onboarding-preview-handoff-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('client-onboarding-preview-handoff-support-tools'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(copySnapshotButton.first);
      await tester.tap(copySnapshotButton.first);
      await tester.pumpAndSettle();

      expect(copiedSnapshot, contains('Client Demo Snapshot'));
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.byKey(const ValueKey('client-onboarding-command-receipt')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('client-onboarding-command-receipt')),
          matching: find.text('Client snapshot copied for command review.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text('Client snapshot copied for command review.'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('client onboarding command deck primes scenario into the form', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.clients,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Demo Mode'));
    await tapVisibleText(tester, 'Demo Mode');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('client-onboarding-command-deck')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-primary-action')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('client-onboarding-primary-action')),
    );
    await tester.pumpAndSettle();

    final clientIdField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Client ID (e.g. CLIENT-001)'),
    );
    expect(clientIdField.controller?.text, isNotEmpty);
    expect(
      find.byKey(const ValueKey('client-onboarding-workflow-actions')),
      findsOneWidget,
    );
  });

  testWidgets('client onboarding preview command auto-fills missing fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.clients,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Demo Mode'));
    await tapVisibleText(tester, 'Demo Mode');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('client-onboarding-preview-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-preview-primary-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-preview-snapshot-band')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-preview-command-context')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-preview-next-move-detail')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('client-onboarding-preview-command-support-shell'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-preview-progress-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-preview-readiness-command')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('client-onboarding-preview-primary-action')),
    );
    await tester.tap(
      find.byKey(const ValueKey('client-onboarding-preview-primary-action')),
    );
    await tester.pumpAndSettle();

    final clientIdField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Client ID (e.g. CLIENT-001)'),
    );
    expect(clientIdField.controller?.text, isNotEmpty);
    expect(
      find.byKey(const ValueKey('client-onboarding-preview-highlights')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('client-onboarding-preview-highlights-command'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('client-onboarding-preview-highlights-supporting'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('client onboarding flow command advances to contact stage', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.clients,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Demo Mode'));
    await tapVisibleText(tester, 'Demo Mode');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Client ID (e.g. CLIENT-001)'),
      'CLIENT-VALLEE',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Legal Entity Name'),
      'MS Vallee Residence',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('client-onboarding-flow-command')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-flow-primary-action')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('client-onboarding-flow-primary-action')),
    );
    await tester.tap(
      find.byKey(const ValueKey('client-onboarding-flow-primary-action')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Sovereign Contact'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-onboarding-flow-stage-2')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('onboarding-step-title-status-0')),
        matching: find.text('READY'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('onboarding-step-title-status-1')),
        matching: find.text('LIVE'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-step-panel-contact-card')),
      findsOneWidget,
    );
  });

  testWidgets(
    'client onboarding contract and messaging controls stay surfaced as command shells',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdministrationPage(
            events: <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.clients,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      await tapVisibleText(tester, '3. Contract');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-onboarding-contract-start-shell')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('client-onboarding-contract-start-status'),
          ),
          matching: find.text('DATE LIVE'),
        ),
        findsOneWidget,
      );

      await tapVisibleText(tester, '4. Messaging');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-onboarding-telegram-bridge-shell')),
        findsOneWidget,
      );
    },
  );

  testWidgets('client onboarding coach command advances to contact cue', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.clients,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Demo Mode'));
    await tapVisibleText(tester, 'Demo Mode');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('client-onboarding-coach-command')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-coach-primary-action')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('client-onboarding-coach-primary-action')),
    );
    await tester.tap(
      find.byKey(const ValueKey('client-onboarding-coach-primary-action')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Sovereign Contact'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-onboarding-coach-stage-2')),
      findsOneWidget,
    );
  });

  testWidgets('client onboarding create pulse surfaces lock shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.clients,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Demo Mode'));
    await tapVisibleText(tester, 'Demo Mode');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    final demoReadyButton = find.widgetWithText(FilledButton, 'Demo Ready 0/7');
    final fallbackDemoReadyButton = find.textContaining('Demo Ready');
    final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
        ? demoReadyButton.first
        : fallbackDemoReadyButton.first;
    await tester.ensureVisible(demoReadyFinder);
    await tester.tap(demoReadyFinder);
    await tester.pumpAndSettle();

    final createClientReadyFinder = find.text('Create Client (Ready)').last;
    await tester.ensureVisible(createClientReadyFinder);
    await tester.tap(createClientReadyFinder);
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const ValueKey('client-onboarding-pulse-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-pulse-next-move')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-onboarding-pulse-progress')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-create-success-title')),
      findsOneWidget,
    );
  });

  testWidgets(
    'site onboarding preview buttons stay disabled until routeable identity is present',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.sites,
            onOpenOperationsForIncident: (reference) {},
            onOpenTacticalForIncident: (reference) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Site Name'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('site-onboarding-command-deck')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-primary-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-preview-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-preview-handoff-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-preview-snapshot-band')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-preview-command-context')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-preview-next-move-detail')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-preview-command-support-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-preview-progress-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-preview-readiness-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-preview-readiness-gates')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-preview-highlights-command'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-preview-highlights-spotlight'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-preview-handoff-support-tools'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-flow-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-coach-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-step-panel-identity-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-field-site-name-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-identity-tools-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-identity-suggestions-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-identity-suggestion-id-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-identity-suggestion-code-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-ops-focus')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-tactical-focus')),
        findsNothing,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Site Name'),
        'Vallee Gatehouse',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Apply Suggestions'));
      await tester.tap(find.text('Apply Suggestions'));
      await tester.pumpAndSettle();

      final siteIdField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Site ID (e.g. SITE-SANDTON)'),
      );
      final siteCodeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Site Code'),
      );
      expect(siteIdField.controller?.text, isNotEmpty);
      expect(siteCodeField.controller?.text, isNotEmpty);
      final identityIdMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('site-onboarding-identity-suggestion-id-micro-value'),
        ),
      );
      final identityCodeMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'site-onboarding-identity-suggestion-code-micro-value',
          ),
        ),
      );
      expect(identityIdMicroValue.data, 'Route live');
      expect(identityCodeMicroValue.data, 'Code live');
      expect(
        find.byKey(const ValueKey('site-onboarding-ops-focus')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-tactical-focus')),
        findsOneWidget,
      );

      await tapVisibleText(tester, '2. Location');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('site-onboarding-layout-url-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-location-integrity-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-location-integrity-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-tactical-footprint-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-coordinate-presets-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-coordinate-preset-sandton-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-geofence-presets-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-geofence-preset-450-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-entry-protocol-templates-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-entry-protocol-estate-gate-card'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'site onboarding demo workflow shelf stays grouped and command-forward',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdministrationPage(
            events: <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.sites,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('site-onboarding-workflow-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-workflow-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-workflow-next-move')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-workflow-primary-tools')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-workflow-support-tools')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('site-onboarding-workflow-primary-tools'),
          ),
          matching: find.text('Launch Demo'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('site-onboarding-workflow-support-tools'),
          ),
          matching: find.text('Copy Snapshot'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'site onboarding location helper command cards seed coordinates geofence and protocol',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.sites,
            onOpenOperationsForIncident: (reference) {},
            onOpenTacticalForIncident: (reference) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      await tapVisibleText(tester, '2. Location');
      await tester.pumpAndSettle();

      final sandtonPreset = find.byKey(
        const ValueKey('site-onboarding-coordinate-preset-sandton-card'),
      );
      await tester.ensureVisible(sandtonPreset);
      await tester.tap(sandtonPreset);
      await tester.pumpAndSettle();

      final latitudeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Latitude'),
      );
      final longitudeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Longitude'),
      );
      expect(latitudeField.controller?.text, '-26.1076');
      expect(longitudeField.controller?.text, '28.0567');
      final coordinateMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'site-onboarding-coordinate-preset-sandton-micro-value',
          ),
        ),
      );
      expect(coordinateMicroValue.data, 'Anchor live');

      final geofencePreset = find.byKey(
        const ValueKey('site-onboarding-geofence-preset-450-card'),
      );
      await tester.ensureVisible(geofencePreset);
      await tester.tap(geofencePreset);
      await tester.pumpAndSettle();

      final geofenceField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Geofence Radius (meters)'),
      );
      expect(geofenceField.controller?.text, '450');
      final geofenceMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('site-onboarding-geofence-preset-450-micro-value'),
        ),
      );
      expect(geofenceMicroValue.data, 'Perimeter live');
      final integrityGeofenceMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'site-onboarding-location-integrity-geofence-micro-value',
          ),
        ),
      );
      expect(integrityGeofenceMicroValue.data, 'Perimeter live');

      await tester.ensureVisible(
        find.byKey(
          const ValueKey('site-onboarding-location-integrity-url-action'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey('site-onboarding-location-integrity-url-action'),
        ),
      );
      await tester.pumpAndSettle();

      final mapUrlField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Site Layout Map URL'),
      );
      expect(mapUrlField.controller?.text, isNotEmpty);

      final protocolPreset = find.byKey(
        const ValueKey('site-onboarding-entry-protocol-estate-gate-card'),
      );
      await tester.ensureVisible(protocolPreset);
      await tester.tap(protocolPreset);
      await tester.pumpAndSettle();

      final entryProtocolField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Entry Protocol'),
      );
      expect(
        entryProtocolField.controller?.text,
        'Main gate intercom to control room. Visitor lane after ID verification.',
      );
      final protocolMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'site-onboarding-entry-protocol-estate-gate-micro-value',
          ),
        ),
      );
      expect(protocolMicroValue.data, 'Flow live');
    },
  );

  testWidgets(
    'site onboarding risk workspace stays command-forward and applies ops pack across stages',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.sites,
            onOpenOperationsForIncident: (reference) {},
            onOpenTacticalForIncident: (reference) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Site Name'),
        'Vallee Gatehouse',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Apply Suggestions'));
      await tester.tap(find.text('Apply Suggestions'));
      await tester.pumpAndSettle();

      await tapVisibleText(tester, '3. Risk Profiler');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('site-onboarding-risk-profile-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-risk-profile-industrial-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-risk-timers-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-risk-timers-command-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-risk-timers-nudge-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-risk-timers-escalation-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-risk-outcome-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-risk-outcome-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-risk-response-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-risk-response-command-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-site-telegram-bridge-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-sla-promise-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-sla-command-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-sla-next-move')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-risk-outcome-profile-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-risk-outcome-next-move')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-risk-outcome-profile-micro-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-risk-response-escalation-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-sla-first-action-shell')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(
          const ValueKey('site-onboarding-risk-profile-industrial-action'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey('site-onboarding-risk-profile-industrial-action'),
        ),
      );
      await tester.pumpAndSettle();

      final industrialMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('site-onboarding-risk-profile-industrial-micro-value'),
        ),
      );
      expect(industrialMicroValue.data, 'Profile live');
      final outcomeProfileMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('site-onboarding-risk-outcome-profile-micro-value'),
        ),
      );
      expect(outcomeProfileMicroValue.data, 'Profile live');
      final responseEscalationMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'site-onboarding-risk-response-escalation-micro-value',
          ),
        ),
      );
      expect(responseEscalationMicroValue.data, 'Escalation live');

      final nudgeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Guard Nudge Frequency (min)'),
      );
      final escalationField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Escalation Trigger (min)'),
      );
      expect(nudgeField.controller?.text, '10');
      expect(escalationField.controller?.text, '1');

      await tester.enterText(
        find.widgetWithText(TextField, 'Guard Nudge Frequency (min)'),
        '18',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Escalation Trigger (min)'),
        '4',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(
          const ValueKey('site-onboarding-risk-timers-profile-action'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey('site-onboarding-risk-timers-profile-action'),
        ),
      );
      await tester.pumpAndSettle();

      final resetNudgeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Guard Nudge Frequency (min)'),
      );
      final resetEscalationField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Escalation Trigger (min)'),
      );
      expect(resetNudgeField.controller?.text, '10');
      expect(resetEscalationField.controller?.text, '1');

      await tester.ensureVisible(
        find.byKey(
          const ValueKey('site-onboarding-risk-timers-primary-action'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey('site-onboarding-risk-timers-primary-action'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, '2. Location');
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('site-onboarding-location-integrity-geofence-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-location-integrity-next-move'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('site-onboarding-tactical-footprint-next-move'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('site-onboarding-tactical-footprint-shell')),
        findsOneWidget,
      );

      final geofenceField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Geofence Radius (meters)'),
      );
      final entryProtocolField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Entry Protocol'),
      );
      final mapUrlField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Site Layout Map URL'),
      );
      expect(geofenceField.controller?.text, '450');
      expect(entryProtocolField.controller?.text, isNotEmpty);
      expect(mapUrlField.controller?.text, isNotEmpty);
    },
  );

  testWidgets('site onboarding sla promise card routes scoped operations', (
    tester,
  ) async {
    String? openedOperationsReference;

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.sites,
          onOpenOperationsForIncident: (reference) {
            openedOperationsReference = reference;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Site Name'),
      'Vallee Gatehouse',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Apply Suggestions'));
    await tester.tap(find.text('Apply Suggestions'));
    await tester.pumpAndSettle();

    await tapVisibleText(tester, '3. Risk Profiler');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('site-onboarding-sla-promise-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('site-onboarding-sla-command-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('site-onboarding-sla-operations-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('site-onboarding-sla-copy-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('site-onboarding-sla-first-action-shell')),
      findsOneWidget,
    );

    final operationsAction = find.byKey(
      const ValueKey('site-onboarding-sla-operations-action'),
    );
    await tester.ensureVisible(operationsAction);
    await tester.pumpAndSettle();
    await tester.tap(operationsAction);
    await tester.pumpAndSettle();

    expect(openedOperationsReference, 'SITE-VALLEE-GATEHOUSE');
  });

  testWidgets(
    'employee onboarding preview buttons stay disabled until routeable identity is present',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
            onOpenOperationsForIncident: (reference) {},
            onOpenTacticalForIncident: (reference) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Employee Code'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('employee-onboarding-command-deck')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-primary-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-preview-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-handoff-command'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-preview-snapshot-band')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-command-context'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-next-move-detail'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-command-support-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-progress-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-readiness-command'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-readiness-gates'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-highlights-command'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-highlights-spotlight'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-preview-handoff-support-tools'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-workflow-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-workflow-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-workflow-next-move')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-workflow-support-tools'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-flow-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-coach-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-step-panel-identity-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-field-employee-code-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-dob-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-dob-summary-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-identity-quick-picks-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-identity-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-client-quick-picks-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-client-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-role-quick-picks-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-role-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-scope-focus-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-dob-command-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-identity-registry-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-identity-registry-command-shell'),
        ),
        findsOneWidget,
      );
      expectOutlinedButtonDisabled(tester, 'Open Operations');
      expectOutlinedButtonDisabled(tester, 'Open Tactical');

      await tester.enterText(
        find.widgetWithText(TextField, 'Employee Code'),
        'EMP-VALLEE-01',
      );
      await tester.pumpAndSettle();

      expectOutlinedButtonEnabled(tester, 'Open Operations');
      expectOutlinedButtonEnabled(tester, 'Open Tactical');

      await tapVisibleText(tester, '3. Assignment');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('employee-onboarding-driver-license-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-pdp-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-mobility-registry-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-driver-license-command-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-driver-credential-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-pdp-command-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-psira-expiry-summary-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-quick-picks-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-registry-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-override-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-route-input-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-route-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-summary-card'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'employee onboarding identity quick picks stage role code and identity pack',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
            onOpenOperationsForIncident: (reference) {},
            onOpenTacticalForIncident: (reference) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('employee-onboarding-client-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-role-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-identity-quick-focus-shell'),
        ),
        findsOneWidget,
      );

      final clientQuickPick = find.byKey(
        const ValueKey('employee-onboarding-client-clt-002-card'),
      );
      await tester.ensureVisible(clientQuickPick);
      await tester.tap(clientQuickPick);
      await tester.pumpAndSettle();

      final clientDropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).first,
      );
      expect(clientDropdown.value, 'CLT-002');
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-client-clt-002-micro-shell'),
        ),
        findsOneWidget,
      );
      final clientMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-client-clt-002-micro-value'),
        ),
      );
      expect(clientMicroValue.data, 'Stage identity');

      final rolePalettePick = find.byKey(
        const ValueKey('employee-onboarding-role-controller-card'),
      );
      await tester.ensureVisible(rolePalettePick);
      await tester.tap(rolePalettePick);
      await tester.pumpAndSettle();

      final roleDropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).at(1),
      );
      expect(roleDropdown.value, 'controller');
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-role-controller-micro-shell'),
        ),
        findsOneWidget,
      );
      final rolePaletteMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-role-controller-micro-value'),
        ),
      );
      expect(rolePaletteMicroValue.data, 'Stage registry');

      final roleQuickPick = find.byKey(
        const ValueKey('employee-onboarding-identity-role-card'),
      );
      await tester.ensureVisible(roleQuickPick);
      await tester.tap(roleQuickPick);
      await tester.pumpAndSettle();

      expect(find.text('REACTION OFFICER'), findsWidgets);
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-identity-registry-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-identity-registry-command-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-scope-focus-shell')),
        findsOneWidget,
      );

      final stageScenarioRole = find.byKey(
        const ValueKey('employee-onboarding-role-quick-focus-stage-scenario'),
      );
      await tester.ensureVisible(stageScenarioRole);
      await tester.tap(stageScenarioRole);
      await tester.pumpAndSettle();

      final restagedRoleDropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).at(1),
      );
      expect(restagedRoleDropdown.value, 'reaction_officer');
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-identity-role-micro-shell'),
        ),
        findsOneWidget,
      );
      final roleMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-identity-role-micro-value'),
        ),
      );
      expect(roleMicroValue.data, 'Scope live');

      final codeQuickPick = find.byKey(
        const ValueKey('employee-onboarding-identity-code-card'),
      );
      await tester.ensureVisible(codeQuickPick);
      await tester.tap(codeQuickPick);
      await tester.pumpAndSettle();

      final employeeCodeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Employee Code'),
      );
      expect(employeeCodeField.controller?.text, 'DEMO-EMP-REACT');
      final codeMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-identity-code-micro-value'),
        ),
      );
      expect(codeMicroValue.data, 'Registry live');

      final identityPack = find.byKey(
        const ValueKey('employee-onboarding-identity-pack-card'),
      );
      await tester.ensureVisible(identityPack);
      await tester.tap(identityPack);
      await tester.pumpAndSettle();

      final fullNameField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Full Name'),
      );
      final surnameField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Surname'),
      );
      final idField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'ID / Passport Number'),
      );
      expect(fullNameField.controller?.text, 'Kagiso');
      expect(surnameField.controller?.text, 'Molefe');
      expect(idField.controller?.text, '8808085501081');
      final identityMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-identity-pack-micro-value'),
        ),
      );
      expect(identityMicroValue.data, 'Proof live');

      final clearRegistry = find.byKey(
        const ValueKey('employee-onboarding-identity-registry-clear'),
      );
      await tester.ensureVisible(clearRegistry);
      await tester.tap(clearRegistry);
      await tester.pumpAndSettle();

      final clearedEmployeeCodeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Employee Code'),
      );
      final clearedFullNameField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Full Name'),
      );
      final clearedSurnameField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Surname'),
      );
      final clearedIdField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'ID / Passport Number'),
      );
      expect(clearedEmployeeCodeField.controller?.text, isEmpty);
      expect(clearedFullNameField.controller?.text, isEmpty);
      expect(clearedSurnameField.controller?.text, isEmpty);
      expect(clearedIdField.controller?.text, isEmpty);

      final stageRegistry = find.byKey(
        const ValueKey('employee-onboarding-identity-registry-stage'),
      );
      await tester.ensureVisible(stageRegistry);
      await tester.tap(stageRegistry);
      await tester.pumpAndSettle();

      final restagedEmployeeCodeField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Employee Code'),
      );
      final restagedFullNameField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Full Name'),
      );
      final restagedSurnameField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Surname'),
      );
      final restagedIdField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'ID / Passport Number'),
      );
      expect(restagedEmployeeCodeField.controller?.text, 'DEMO-EMP-REACT');
      expect(restagedFullNameField.controller?.text, 'Kagiso');
      expect(restagedSurnameField.controller?.text, 'Molefe');
      expect(restagedIdField.controller?.text, '8808085501081');

      final stagePrimaryClient = find.byKey(
        const ValueKey('employee-onboarding-client-quick-focus-stage-first'),
      );
      await tester.ensureVisible(stagePrimaryClient);
      await tester.tap(stagePrimaryClient);
      await tester.pumpAndSettle();

      final resetClientDropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).first,
      );
      expect(resetClientDropdown.value, 'CLT-001');
    },
  );

  testWidgets(
    'employee onboarding compliance anchors stage renew and clear readiness dates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
            onOpenOperationsForIncident: (reference) {},
            onOpenTacticalForIncident: (reference) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final reactionOfficerRole = find.byKey(
        const ValueKey('employee-onboarding-role-reaction-officer-card'),
      );
      await tester.ensureVisible(reactionOfficerRole);
      await tester.tap(reactionOfficerRole);
      await tester.pumpAndSettle();

      final stageDob = find.byKey(
        const ValueKey('employee-onboarding-dob-stage-demo'),
      );
      await tester.ensureVisible(stageDob);
      await tester.tap(stageDob);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('employee-onboarding-dob-summary-status')),
        findsOneWidget,
      );
      expect(find.text('1988-08-08'), findsOneWidget);

      await tapVisibleText(tester, '2. PSIRA & Compliance');
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('employee-onboarding-compliance-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-compliance-command-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-compliance-registry-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-compliance-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-compliance-override-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-psira-expiry-command-shell'),
        ),
        findsOneWidget,
      );

      final stageCompliancePack = find.byKey(
        const ValueKey('employee-onboarding-compliance-quick-focus-stage-pack'),
      );
      await tester.ensureVisible(stageCompliancePack);
      await tester.tap(stageCompliancePack);
      await tester.pumpAndSettle();

      final complianceGradeDropdownFinder = find.descendant(
        of: find.byKey(
          const ValueKey('employee-onboarding-compliance-override-shell'),
        ),
        matching: find.byType(DropdownButton<String>),
      );
      final psiraGradeDropdown = tester.widget<DropdownButton<String>>(
        complianceGradeDropdownFinder.first,
      );
      expect(psiraGradeDropdown.value, 'B');
      expect(
        find.byKey(
          const ValueKey(
            'employee-onboarding-compliance-suggest-number-micro-shell',
          ),
        ),
        findsOneWidget,
      );
      final complianceNumberMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'employee-onboarding-compliance-suggest-number-micro-value',
          ),
        ),
      );
      final complianceGradeMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'employee-onboarding-compliance-role-grade-micro-value',
          ),
        ),
      );
      expect(complianceNumberMicroValue.data, 'Registry live');
      expect(complianceGradeMicroValue.data, 'Grade live');

      final seededPsiraField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'PSIRA Number'),
      );
      expect(seededPsiraField.controller?.text, isNotEmpty);

      final stageCompliance = find.byKey(
        const ValueKey('employee-onboarding-compliance-stage'),
      );
      await tester.ensureVisible(stageCompliance);
      await tester.tap(stageCompliance);
      await tester.pumpAndSettle();

      final psiraField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'PSIRA Number'),
      );
      expect(psiraField.controller?.text, isNotEmpty);
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-compliance-number-status'),
        ),
        findsOneWidget,
      );

      final renewPsira = find.byKey(
        const ValueKey('employee-onboarding-psira-expiry-renew'),
      );
      await tester.ensureVisible(renewPsira);
      await tester.tap(renewPsira);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('employee-onboarding-psira-expiry-summary-status'),
        ),
        findsOneWidget,
      );
      final psiraSummaryValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-psira-expiry-summary-value'),
        ),
      );
      expect(psiraSummaryValue.data, isNot('Compliance seal not staged'));

      final clearPsira = find.byKey(
        const ValueKey('employee-onboarding-psira-expiry-clear'),
      );
      await tester.ensureVisible(clearPsira);
      await tester.tap(clearPsira);
      await tester.pumpAndSettle();

      expect(find.text('Compliance seal not staged'), findsOneWidget);

      final clearCompliance = find.byKey(
        const ValueKey('employee-onboarding-compliance-clear'),
      );
      await tester.ensureVisible(clearCompliance);
      await tester.tap(clearCompliance);
      await tester.pumpAndSettle();

      final clearedPsiraField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'PSIRA Number'),
      );
      expect(clearedPsiraField.controller?.text, isEmpty);

      final clearComplianceOverrides = find.byKey(
        const ValueKey('employee-onboarding-compliance-override-clear'),
      );
      await tester.ensureVisible(clearComplianceOverrides);
      await tester.tap(clearComplianceOverrides);
      await tester.pumpAndSettle();

      final clearedOverridePsiraField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'PSIRA Number'),
      );
      final resetGradeDropdown = tester.widget<DropdownButton<String>>(
        complianceGradeDropdownFinder.first,
      );
      expect(clearedOverridePsiraField.controller?.text, isEmpty);
      expect(resetGradeDropdown.value, 'C');
    },
  );

  testWidgets(
    'employee onboarding assignment command cards stage mobility and assignment',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
            onOpenOperationsForIncident: (reference) {},
            onOpenTacticalForIncident: (reference) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      await tapVisibleText(tester, '3. Assignment');
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('employee-onboarding-mobility-registry-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-driver-license-command-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-driver-credential-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee-onboarding-pdp-command-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-route-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-quick-focus-shell'),
        ),
        findsOneWidget,
      );

      final stagePrimaryAssignment = find.byKey(
        const ValueKey(
          'employee-onboarding-assignment-quick-focus-stage-first',
        ),
      );
      await tester.ensureVisible(stagePrimaryAssignment);
      await tester.tap(stagePrimaryAssignment);
      await tester.pumpAndSettle();

      final assignmentDropdownFinder = find.descendant(
        of: find.byKey(
          const ValueKey('employee-onboarding-assignment-route-dropdown'),
        ),
        matching: find.byType(DropdownButton<String>),
      );
      final stagedAssignmentDropdown = tester.widget<DropdownButton<String>>(
        assignmentDropdownFinder.first,
      );
      expect(stagedAssignmentDropdown.value, isNotEmpty);
      expect(
        find.byKey(
          const ValueKey(
            'employee-onboarding-assignment-site-wtf-main-micro-shell',
          ),
        ),
        findsOneWidget,
      );
      final assignmentMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey(
            'employee-onboarding-assignment-site-wtf-main-micro-value',
          ),
        ),
      );
      expect(assignmentMicroValue.data, 'Route live');

      final holdStandby = find.byKey(
        const ValueKey('employee-onboarding-assignment-quick-focus-standby'),
      );
      await tester.ensureVisible(holdStandby);
      await tester.tap(holdStandby);
      await tester.pumpAndSettle();

      final standbyAssignmentDropdown = tester.widget<DropdownButton<String>>(
        assignmentDropdownFinder.first,
      );
      expect(standbyAssignmentDropdown.value, '');

      final enableVehicle = find.byKey(
        const ValueKey('employee-onboarding-driver-license-enable'),
      );
      await tester.ensureVisible(enableVehicle);
      await tester.tap(enableVehicle);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'License Code'), findsOneWidget);

      final disableVehicle = find.byKey(
        const ValueKey('employee-onboarding-driver-license-disable'),
      );
      await tester.ensureVisible(disableVehicle);
      await tester.tap(disableVehicle);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'License Code'), findsNothing);

      final stageDriverPack = find.byKey(
        const ValueKey('employee-onboarding-mobility-registry-stage-driver'),
      );
      await tester.ensureVisible(stageDriverPack);
      await tester.tap(stageDriverPack);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'License Code'), findsOneWidget);
      final seededLicenseField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'License Code'),
      );
      expect(seededLicenseField.controller?.text, 'Code 10');
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-license-expiry-summary-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-license-expiry-command-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-driver-license-summary-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'employee-onboarding-mobility-registry-license-expiry-status',
          ),
        ),
        findsOneWidget,
      );

      final clearDriverCode = find.byKey(
        const ValueKey('employee-onboarding-driver-credential-clear'),
      );
      await tester.ensureVisible(clearDriverCode);
      await tester.tap(clearDriverCode);
      await tester.pumpAndSettle();

      final clearedLicenseField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'License Code'),
      );
      expect(clearedLicenseField.controller?.text, isEmpty);

      final stageDriverCode = find.byKey(
        const ValueKey('employee-onboarding-driver-credential-stage'),
      );
      await tester.ensureVisible(stageDriverCode);
      await tester.tap(stageDriverCode);
      await tester.pumpAndSettle();

      final restagedLicenseField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'License Code'),
      );
      expect(restagedLicenseField.controller?.text, 'Code 10');

      final clearLicenseExpiry = find.byKey(
        const ValueKey('employee-onboarding-license-expiry-clear'),
      );
      await tester.ensureVisible(clearLicenseExpiry);
      await tester.tap(clearLicenseExpiry);
      await tester.pumpAndSettle();

      final licenseExpiryValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-license-expiry-summary-value'),
        ),
      );
      expect(licenseExpiryValue.data, 'License expiry not staged');

      final stageLicenseExpiry = find.byKey(
        const ValueKey('employee-onboarding-license-expiry-stage'),
      );
      await tester.ensureVisible(stageLicenseExpiry);
      await tester.tap(stageLicenseExpiry);
      await tester.pumpAndSettle();

      final restagedLicenseExpiryValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-license-expiry-summary-value'),
        ),
      );
      expect(
        restagedLicenseExpiryValue.data,
        isNot('License expiry not staged'),
      );

      final stagePdpPack = find.byKey(
        const ValueKey('employee-onboarding-mobility-registry-stage-pdp'),
      );
      await tester.ensureVisible(stagePdpPack);
      await tester.tap(stagePdpPack);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('employee-onboarding-pdp-expiry-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-pdp-expiry-summary-card'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-pdp-expiry-command-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-quick-picks-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-quick-picks-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-quick-focus-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-registry-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-override-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-override-device-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-override-phone-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-contact-override-email-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-route-input-shell'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-route-dropdown'),
        ),
        findsOneWidget,
      );

      final stageFullContact = find.byKey(
        const ValueKey('employee-onboarding-contact-quick-focus-stage-all'),
      );
      await tester.ensureVisible(stageFullContact);
      await tester.tap(stageFullContact);
      await tester.pumpAndSettle();

      final quickFocusDeviceField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Device UID'),
      );
      final quickFocusPhoneField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Phone'),
      );
      final quickFocusEmailField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Email'),
      );
      expect(quickFocusDeviceField.controller?.text, 'BV5300P-DEMO');
      expect(quickFocusPhoneField.controller?.text, '+27 82 711 2233');
      expect(
        quickFocusEmailField.controller?.text,
        'kagiso.demo@onyx-security.co.za',
      );
      final contactDeviceMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-contact-device-micro-value'),
        ),
      );
      final contactPhoneMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-contact-phone-micro-value'),
        ),
      );
      final contactEmailMicroValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-contact-email-micro-value'),
        ),
      );
      expect(contactDeviceMicroValue.data, 'Channel live');
      expect(contactPhoneMicroValue.data, 'Channel live');
      expect(contactEmailMicroValue.data, 'Channel live');

      final disablePdp = find.byKey(
        const ValueKey('employee-onboarding-pdp-disable'),
      );
      await tester.ensureVisible(disablePdp);
      await tester.tap(disablePdp);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('employee-onboarding-pdp-expiry-shell')),
        findsNothing,
      );

      final enablePdp = find.byKey(
        const ValueKey('employee-onboarding-pdp-enable'),
      );
      await tester.ensureVisible(enablePdp);
      await tester.tap(enablePdp);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('employee-onboarding-pdp-expiry-shell')),
        findsOneWidget,
      );

      final clearPdpExpiry = find.byKey(
        const ValueKey('employee-onboarding-pdp-expiry-clear'),
      );
      await tester.ensureVisible(clearPdpExpiry);
      await tester.tap(clearPdpExpiry);
      await tester.pumpAndSettle();

      final pdpExpiryValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-pdp-expiry-summary-value'),
        ),
      );
      expect(pdpExpiryValue.data, 'PDP clearance window not staged');

      final stagePdpExpiry = find.byKey(
        const ValueKey('employee-onboarding-pdp-expiry-stage'),
      );
      await tester.ensureVisible(stagePdpExpiry);
      await tester.tap(stagePdpExpiry);
      await tester.pumpAndSettle();

      final restagedPdpExpiryValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-pdp-expiry-summary-value'),
        ),
      );
      expect(
        restagedPdpExpiryValue.data,
        isNot('PDP clearance window not staged'),
      );

      final stageContact = find.byKey(
        const ValueKey('employee-onboarding-contact-registry-stage'),
      );
      await tester.ensureVisible(stageContact);
      await tester.tap(stageContact);
      await tester.pumpAndSettle();

      final stagedDeviceField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Device UID'),
      );
      final stagedPhoneField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Phone'),
      );
      final stagedEmailField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Email'),
      );
      expect(stagedDeviceField.controller?.text, 'BV5300P-DEMO');
      expect(stagedPhoneField.controller?.text, '+27 82 711 2233');
      expect(
        stagedEmailField.controller?.text,
        'kagiso.demo@onyx-security.co.za',
      );

      final clearContact = find.byKey(
        const ValueKey('employee-onboarding-contact-registry-clear'),
      );
      await tester.ensureVisible(clearContact);
      await tester.tap(clearContact);
      await tester.pumpAndSettle();

      final clearedDeviceField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Device UID'),
      );
      final clearedPhoneField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Phone'),
      );
      final clearedEmailField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Email'),
      );
      expect(clearedDeviceField.controller?.text, isEmpty);
      expect(clearedPhoneField.controller?.text, isEmpty);
      expect(clearedEmailField.controller?.text, isEmpty);

      final stageDeviceOverride = find.byKey(
        const ValueKey('employee-onboarding-contact-override-stage-device'),
      );
      await tester.ensureVisible(stageDeviceOverride);
      await tester.tap(stageDeviceOverride);
      await tester.pumpAndSettle();

      final stagePhoneOverride = find.byKey(
        const ValueKey('employee-onboarding-contact-override-stage-phone'),
      );
      await tester.ensureVisible(stagePhoneOverride);
      await tester.tap(stagePhoneOverride);
      await tester.pumpAndSettle();

      final stageEmailOverride = find.byKey(
        const ValueKey('employee-onboarding-contact-override-stage-email'),
      );
      await tester.ensureVisible(stageEmailOverride);
      await tester.tap(stageEmailOverride);
      await tester.pumpAndSettle();

      final overrideDeviceField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Device UID'),
      );
      final overridePhoneField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Phone'),
      );
      final overrideEmailField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Email'),
      );
      expect(overrideDeviceField.controller?.text, 'BV5300P-DEMO');
      expect(overridePhoneField.controller?.text, '+27 82 711 2233');
      expect(
        overrideEmailField.controller?.text,
        'kagiso.demo@onyx-security.co.za',
      );

      final clearOverrides = find.byKey(
        const ValueKey('employee-onboarding-contact-override-clear'),
      );
      await tester.ensureVisible(clearOverrides);
      await tester.tap(clearOverrides);
      await tester.pumpAndSettle();

      final clearedOverrideDeviceField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Device UID'),
      );
      final clearedOverridePhoneField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Phone'),
      );
      final clearedOverrideEmailField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Contact Email'),
      );
      expect(clearedOverrideDeviceField.controller?.text, isEmpty);
      expect(clearedOverridePhoneField.controller?.text, isEmpty);
      expect(clearedOverrideEmailField.controller?.text, isEmpty);

      final firstRoute = find.byKey(
        const ValueKey('employee-onboarding-assignment-route-first-site'),
      );
      await tester.ensureVisible(firstRoute);
      await tester.tap(firstRoute);
      await tester.pumpAndSettle();

      final routeSummaryValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-route-summary-value'),
        ),
      );
      expect(routeSummaryValue.data, contains('Waterfall Estate Main'));

      final standbyRoute = find.byKey(
        const ValueKey('employee-onboarding-assignment-route-standby'),
      );
      await tester.ensureVisible(standbyRoute);
      await tester.tap(standbyRoute);
      await tester.pumpAndSettle();

      final standbySummaryValue = tester.widget<Text>(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-route-summary-value'),
        ),
      );
      expect(standbySummaryValue.data, 'Unassigned');

      final siteQuickPick = find.byKey(
        const ValueKey('employee-onboarding-assignment-site-wtf-main-card'),
      );
      await tester.ensureVisible(siteQuickPick);
      await tester.tap(siteQuickPick);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('employee-onboarding-assignment-summary-status'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Waterfall Estate Main'), findsWidgets);
    },
  );

  testWidgets('site partner health row opens drill-in with lane details', (
    tester,
  ) async {
    late Map<String, Object?> checkedPayload;
    String? openedDispatchClientId;
    String? openedDispatchSiteId;
    String? openedDispatchReference;
    List<String>? openedEventIds;
    String? openedSelectedEventId;
    Map<String, String>? openedGovernanceScope;

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[
            PartnerDispatchStatusDeclared(
              eventId: 'evt-partner-0',
              sequence: 3,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 15, 21, 11),
              dispatchId: 'DSP-8821',
              clientId: 'CLT-001',
              regionId: 'GAUTENG',
              siteId: 'WTF-MAIN',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.accepted,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-0',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'evt-partner-1',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 15, 21, 14),
              dispatchId: 'DSP-8821',
              clientId: 'CLT-001',
              regionId: 'GAUTENG',
              siteId: 'WTF-MAIN',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.onSite,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-1',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'evt-partner-2',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 15, 21, 19),
              dispatchId: 'DSP-8821',
              clientId: 'CLT-001',
              regionId: 'GAUTENG',
              siteId: 'WTF-MAIN',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.allClear,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-2',
            ),
          ],
          morningSovereignReportHistory: <SovereignReport>[
            SovereignReport(
              date: '2026-03-14',
              generatedAtUtc: DateTime.utc(2026, 3, 14, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 13, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 14, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 1,
                acceptedCount: 1,
                onSiteCount: 0,
                allClearCount: 0,
                cancelledCount: 1,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLT-001',
                    siteId: 'WTF-MAIN',
                    partnerLabel: 'PARTNER • Alpha',
                    dispatchCount: 1,
                    strongCount: 0,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 1,
                    averageAcceptedDelayMinutes: 12.0,
                    averageOnSiteDelayMinutes: 22.0,
                    summaryLine:
                        'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
                  ),
                ],
              ),
            ),
            SovereignReport(
              date: '2026-03-15',
              generatedAtUtc: DateTime.utc(2026, 3, 15, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 14, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 15, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 3,
                acceptedCount: 1,
                onSiteCount: 1,
                allClearCount: 1,
                cancelledCount: 0,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLT-001',
                    siteId: 'WTF-MAIN',
                    partnerLabel: 'PARTNER • Alpha',
                    dispatchCount: 1,
                    strongCount: 1,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 0,
                    averageAcceptedDelayMinutes: 4.0,
                    averageOnSiteDelayMinutes: 10.0,
                    summaryLine:
                        'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
                  ),
                ],
              ),
            ),
          ],
          supabaseReady: false,
          initialTab: AdministrationPageTab.sites,
          initialSitePartnerEndpointCounts: <String, int>{
            'CLT-001::WTF-MAIN': 1,
          },
          initialSitePartnerChatcheckStatus: <String, String>{
            'CLT-001::WTF-MAIN': 'PASS (partner lane linked)',
          },
          initialSitePartnerLaneDetails: <String, List<String>>{
            'CLT-001::WTF-MAIN': <String>[
              'PARTNER • Alpha • chat=-1001234567890 • thread=77',
            ],
          },
          onCheckPartnerTelegramEndpoint:
              ({
                required clientId,
                required siteId,
                required chatId,
                int? threadId,
              }) async {
                checkedPayload = <String, Object?>{
                  'clientId': clientId,
                  'siteId': siteId,
                  'chatId': chatId,
                  'threadId': threadId,
                };
                return 'PASS (partner lane linked)';
              },
          onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
            openedDispatchClientId = clientId;
            openedDispatchSiteId = siteId;
            openedDispatchReference = incidentReference;
          },
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
          onOpenGovernanceForPartnerScope: (clientId, siteId, partnerLabel) {
            openedGovernanceScope = <String, String>{
              'clientId': clientId,
              'siteId': siteId,
              'partnerLabel': partnerLabel,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Command Owner: Waterfall Estates Group'), findsWidgets);
    expect(find.text('Geo Anchor: -26.0285, 28.1122'), findsOneWidget);
    await tapVisibleText(tester, 'Waterfall Estate Main (WTF-MAIN)');
    await tester.pumpAndSettle();

    expect(find.textContaining('Partner Dispatch Detail'), findsOneWidget);
    expect(
      find.text('PARTNER • Alpha • chat=-1001234567890 • thread=77'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '2026-03-15 21:14 UTC • PARTNER • Alpha • ON SITE • @partner.alpha • dispatch=DSP-8821',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-dispatch-progression-card')),
      findsOneWidget,
    );
    expect(find.text('Dispatch progression'), findsOneWidget);
    expect(find.text('7-day trend'), findsOneWidget);
    expect(find.text('DSP-8821'), findsWidgets);
    expect(
      find.textContaining('PARTNER • Alpha • Latest ALL CLEAR'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-progress-accepted')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-progress-onSite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-progress-allClear')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-progress-cancelled')),
      findsOneWidget,
    );
    expect(find.text('IMPROVING'), findsOneWidget);
    expect(
      find.text('Acceptance timing improved against the prior 7-day average.'),
      findsOneWidget,
    );
    expect(find.text('Open Governance Scope'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    await tapVisibleText(tester, 'Check lane');
    await tester.pumpAndSettle();

    expect(checkedPayload['clientId'], 'CLT-001');
    expect(checkedPayload['siteId'], 'WTF-MAIN');
    expect(checkedPayload['chatId'], '-1001234567890');
    expect(checkedPayload['threadId'], 77);
    expect(
      find.text('Current health: PASS (partner lane linked)'),
      findsOneWidget,
    );

    await tapVisibleText(tester, 'Open Dispatch Scope');
    await tester.pumpAndSettle();

    expect(openedDispatchClientId, 'CLT-001');
    expect(openedDispatchSiteId, 'WTF-MAIN');
    expect(openedDispatchReference, isNull);

    await tapVisibleText(tester, 'Waterfall Estate Main (WTF-MAIN)');
    await tester.pumpAndSettle();
    await tapVisibleText(tester, 'Open Governance Scope');
    await tester.pumpAndSettle();

    expect(openedGovernanceScope, <String, String>{
      'clientId': 'CLT-001',
      'siteId': 'WTF-MAIN',
      'partnerLabel': 'PARTNER • Alpha',
    });
    expect(
      find.textContaining('Opening Governance for WTF-MAIN'),
      findsOneWidget,
    );

    await tapVisibleText(tester, 'Waterfall Estate Main (WTF-MAIN)');
    await tester.pumpAndSettle();
    await tapVisibleText(tester, 'Open Events Review');
    await tester.pumpAndSettle();

    expect(openedEventIds, <String>[
      'evt-partner-2',
      'evt-partner-1',
      'evt-partner-0',
    ]);
    expect(openedSelectedEventId, 'evt-partner-2');
  });

  testWidgets('site partner health row falls back to scoped dispatch route', (
    tester,
  ) async {
    String? openedDispatchClientId;
    String? openedDispatchSiteId;

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[
            PartnerDispatchStatusDeclared(
              eventId: 'evt-partner-2',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 15, 21, 19),
              dispatchId: 'DSP-8821',
              clientId: 'CLT-001',
              regionId: 'GAUTENG',
              siteId: 'WTF-MAIN',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.allClear,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-2',
            ),
          ],
          supabaseReady: false,
          initialTab: AdministrationPageTab.sites,
          initialSitePartnerEndpointCounts: const <String, int>{
            'CLT-001::WTF-MAIN': 1,
          },
          initialSitePartnerChatcheckStatus: const <String, String>{
            'CLT-001::WTF-MAIN': 'PASS (partner lane linked)',
          },
          initialSitePartnerLaneDetails: const <String, List<String>>{
            'CLT-001::WTF-MAIN': <String>[
              'PARTNER • Alpha • chat=-1001234567890 • thread=77',
            ],
          },
          onOpenDispatchesForScope: (clientId, siteId) {
            openedDispatchClientId = clientId;
            openedDispatchSiteId = siteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'Waterfall Estate Main (WTF-MAIN)');
    await tester.pumpAndSettle();

    expect(find.textContaining('Partner Dispatch Detail'), findsOneWidget);
    expect(find.text('Open Dispatches'), findsOneWidget);

    await tapVisibleText(tester, 'Open Dispatches');
    await tester.pumpAndSettle();

    expect(openedDispatchClientId, 'CLT-001');
    expect(openedDispatchSiteId, 'WTF-MAIN');
  });

  testWidgets('administration page reports tab changes to parent state', (
    tester,
  ) async {
    AdministrationPageTab selectedTab = AdministrationPageTab.guards;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              initialTab: selectedTab,
              onTabChanged: (value) {
                setState(() {
                  selectedTab = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(selectedTab, AdministrationPageTab.guards);
    expect(find.textContaining('Thabo Mokoena'), findsOneWidget);

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    expect(selectedTab, AdministrationPageTab.system);
    expect(find.text('System Information'), findsOneWidget);
    expect(find.textContaining('Thabo Mokoena'), findsNothing);
  });

  testWidgets(
    'administration page persists selected tab through parent-owned remounts',
    (tester) async {
      AdministrationPageTab selectedTab = AdministrationPageTab.system;
      var showAdmin = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAdmin = !showAdmin;
                      });
                    },
                    child: const Text('Toggle admin'),
                  ),
                  Expanded(
                    child: showAdmin
                        ? AdministrationPage(
                            events: const <DispatchEvent>[],
                            supabaseReady: false,
                            initialTab: selectedTab,
                            onTabChanged: (value) {
                              setState(() {
                                selectedTab = value;
                              });
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('System Information'), findsOneWidget);
      expect(find.textContaining('Thabo Mokoena'), findsNothing);

      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();

      expect(selectedTab, AdministrationPageTab.system);
      expect(find.text('System Information'), findsOneWidget);
      expect(find.textContaining('Thabo Mokoena'), findsNothing);
    },
  );

  testWidgets('administration page filters guards by search query', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Nomsa');
    await tester.pumpAndSettle();

    expect(find.textContaining('Nomsa Khumalo'), findsOneWidget);
    expect(
      find.text('Guard Identity: EMP-443 • Role: supervisor'),
      findsOneWidget,
    );
    expect(
      find.text('Deployment Route: Sandton Estate North • Day (06:00-18:00)'),
      findsOneWidget,
    );
    expect(find.textContaining('Thabo Mokoena'), findsNothing);
  });

  testWidgets('administration page edits guard rows in place', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-edit-guard-GRD-001')),
    );
    await tester.tap(find.byKey(const ValueKey('admin-edit-guard-GRD-001')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('admin-guard-edit-name')),
      'Thabo Mokoena Elite',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-guard-edit-shift-pattern')),
      'Swing (14:00-22:00)',
    );
    await tester.tap(find.byKey(const ValueKey('admin-guard-edit-save')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Thabo Mokoena Elite'), findsOneWidget);
    expect(
      find.textContaining(
        'Deployment Route: Waterfall Estate Main • Swing (14:00-22:00)',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
        matching: find.text('Guard EMP-441 updated.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('administration page edits site rows in place', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'Sites');
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-edit-site-WTF-MAIN')),
    );
    await tester.tap(find.byKey(const ValueKey('admin-edit-site-WTF-MAIN')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('admin-site-edit-name')),
      'Waterfall Estate Command',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-site-edit-geofence')),
      '650',
    );
    await tester.tap(find.byKey(const ValueKey('admin-site-edit-save')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Waterfall Estate Command (WTF-MAIN)'), findsOneWidget);
    expect(
      find.textContaining('Response Anchor: FSK-WTF-001 • Geofence: 650m'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
        matching: find.text('Site WTF-MAIN updated.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'client demo success dialog opens dispatches with client-wide scope',
    (tester) async {
      String? openedDispatchClientId;
      String? openedDispatchSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.clients,
            onOpenDispatchesForScope: (clientId, siteId) {
              openedDispatchClientId = clientId;
              openedDispatchSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/7',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createClientReadyFinder = find.text('Create Client (Ready)').last;
      await tester.ensureVisible(createClientReadyFinder);
      await tester.tap(createClientReadyFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-dispatches'),
        ),
        findsOneWidget,
      );

      final openDispatchesAction = find.byKey(
        const ValueKey('admin-create-success-support-open-dispatches'),
      );
      await tester.ensureVisible(openDispatchesAction);
      await tester.tap(openDispatchesAction);
      await tester.pumpAndSettle();

      expect(openedDispatchClientId, startsWith('DEMO-CLT'));
      expect(openedDispatchSiteId, '');
    },
  );

  testWidgets(
    'client demo success dialog opens reports with client-wide scope',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? openedReportsClientId;
      String? openedReportsSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.clients,
            onOpenReportsForScope: (clientId, siteId) {
              openedReportsClientId = clientId;
              openedReportsSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/7',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createClientReadyFinder = find.text('Create Client (Ready)').last;
      await tester.ensureVisible(createClientReadyFinder);
      await tester.tap(createClientReadyFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-support-open-reports')),
        findsOneWidget,
      );

      final openReportsAction = find.byKey(
        const ValueKey('admin-create-success-support-open-reports'),
      );
      await tester.ensureVisible(openReportsAction);
      await tester.tap(openReportsAction);
      await tester.pumpAndSettle();

      expect(openedReportsClientId, startsWith('DEMO-CLT'));
      expect(openedReportsSiteId, '');
    },
  );

  testWidgets(
    'client demo success dialog opens client view with client-wide scope',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? openedClientId;
      String? openedSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.clients,
            onOpenClientViewForScope: (clientId, siteId) {
              openedClientId = clientId;
              openedSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/7',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createClientReadyFinder = find.text('Create Client (Ready)').last;
      await tester.ensureVisible(createClientReadyFinder);
      await tester.tap(createClientReadyFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-client-view'),
        ),
        findsOneWidget,
      );

      final openClientViewAction = find.byKey(
        const ValueKey('admin-create-success-support-open-client-view'),
      );
      await tester.ensureVisible(openClientViewAction);
      await tester.tap(openClientViewAction);
      await tester.pumpAndSettle();

      expect(openedClientId, startsWith('DEMO-CLT'));
      expect(openedSiteId, '');
    },
  );

  testWidgets(
    'client demo success dialog prioritizes client workflow actions over dispatches',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? openedGovernanceClientId;
      String? openedGovernanceSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.clients,
            onOpenClientViewForScope: (_, _) {},
            onOpenGovernanceForScope: (clientId, siteId) {
              openedGovernanceClientId = clientId;
              openedGovernanceSiteId = siteId;
            },
            onOpenOperationsForScope: (_, _) {},
            onOpenReportsForScope: (_, _) {},
            onOpenTacticalForIncident: (_) {},
            onOpenDispatchesForScope: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/7',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createClientReadyFinder = find.text('Create Client (Ready)').last;
      await tester.ensureVisible(createClientReadyFinder);
      await tester.tap(createClientReadyFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-client-view'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-governance'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-operations'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-support-open-reports')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-tactical'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-dispatches'),
        ),
        findsNothing,
      );

      final openGovernanceAction = find.byKey(
        const ValueKey('admin-create-success-support-open-governance'),
      );
      await tester.ensureVisible(openGovernanceAction);
      await tester.tap(openGovernanceAction);
      await tester.pumpAndSettle();

      expect(openedGovernanceClientId, startsWith('DEMO-CLT'));
      expect(openedGovernanceSiteId, '');
    },
  );

  testWidgets('site demo success dialog prioritizes operations workflow actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? openedTacticalClientId;
    String? openedTacticalSiteId;
    String? openedTacticalIncidentReference;

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.sites,
          onOpenOperationsForScope: (_, _) {},
          onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
            openedTacticalClientId = clientId;
            openedTacticalSiteId = siteId;
            openedTacticalIncidentReference = incidentReference;
          },
          onOpenDispatchesForScope: (_, _) {},
          onOpenGovernanceForScope: (_, _) {},
          onOpenReportsForScope: (_, _) {},
          onOpenClientViewForScope: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Demo Mode'));
    await tapVisibleText(tester, 'Demo Mode');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    final demoReadyButton = find.widgetWithText(FilledButton, 'Demo Ready 0/6');
    final fallbackDemoReadyButton = find.textContaining('Demo Ready');
    final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
        ? demoReadyButton.first
        : fallbackDemoReadyButton.first;
    await tester.ensureVisible(demoReadyFinder);
    await tester.tap(demoReadyFinder);
    await tester.pumpAndSettle();

    final createSiteReadyFinder = find.text('Create Site (Ready)').last;
    await tester.ensureVisible(createSiteReadyFinder);
    await tester.tap(createSiteReadyFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-create-success-title')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-frame')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-header-shell')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-create-success-header-shell')),
        matching: find.text(
          'The generated handoff is sealed and ready for scoped review across the actions below.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-header-status')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-create-success-header-status')),
        matching: find.text('handoff sealed'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-header-chips')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-workflow-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-command-snapshot')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-create-success-command-snapshot')),
        matching: find.text(
          'Scoped handoff review is sealed for command follow-through.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-create-success-command-snapshot')),
        matching: find.text(
          'Handoff posture, focus state, signal count, and sealed review depth stay visible here before the deeper focus and success boards.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-command-state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-command-routes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-highlights-command')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-focus-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-focus-command')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-focus-reference')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-highlights-spotlight')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-highlights-supporting')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-workflow-command')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-create-success-workflow-command')),
        matching: find.text(
          'The strongest scoped handoffs are sealed for review below.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-create-success-workflow-command')),
        matching: find.text(
          'The sealed review path stays separated from the supporting handoffs so the operator can inspect and route cleanly without losing the seeded context.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-support-actions')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('admin-create-success-support-open-operations'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-support-open-tactical')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('admin-create-success-support-open-dispatches'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('admin-create-success-support-open-client-view'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('admin-create-success-support-open-governance'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin-create-success-support-open-reports')),
      findsNothing,
    );

    final openTacticalAction = find.byKey(
      const ValueKey('admin-create-success-support-open-tactical'),
    );
    await tester.ensureVisible(openTacticalAction);
    await tester.tap(openTacticalAction);
    await tester.pumpAndSettle();

    expect(openedTacticalClientId, isNotEmpty);
    expect(openedTacticalSiteId, isNotEmpty);
    expect(openedTacticalIncidentReference, isNull);
  });

  testWidgets(
    'employee demo success dialog prioritizes operations workflow actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? openedOperationsClientId;
      String? openedOperationsSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
            onOpenOperationsForScope: (clientId, siteId) {
              openedOperationsClientId = clientId;
              openedOperationsSiteId = siteId;
            },
            onOpenFleetTacticalScope: (_, _, _) {},
            onOpenDispatchesForScope: (_, _) {},
            onOpenGovernanceForScope: (_, _) {},
            onOpenReportsForScope: (_, _) {},
            onOpenClientViewForScope: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/6',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createEmployeeReadyFinder = find
          .text('Create Employee (Ready)')
          .last;
      await tester.ensureVisible(createEmployeeReadyFinder);
      await tester.tap(createEmployeeReadyFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-operations'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-tactical'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-dispatches'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-client-view'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-governance'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-support-open-reports')),
        findsNothing,
      );

      final openOperationsAction = find.byKey(
        const ValueKey('admin-create-success-support-open-operations'),
      );
      await tester.ensureVisible(openOperationsAction);
      await tester.tap(openOperationsAction);
      await tester.pumpAndSettle();

      expect(openedOperationsClientId, isNotEmpty);
      expect(openedOperationsSiteId, isNotEmpty);
    },
  );

  testWidgets(
    'site demo success dialog only shows the wired scope action set',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? openedDispatchClientId;
      String? openedDispatchSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.sites,
            onOpenDispatchesForScope: (clientId, siteId) {
              openedDispatchClientId = clientId;
              openedDispatchSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final demoReadyButton = find.widgetWithText(
        FilledButton,
        'Demo Ready 0/6',
      );
      final fallbackDemoReadyButton = find.textContaining('Demo Ready');
      final demoReadyFinder = demoReadyButton.evaluate().isNotEmpty
          ? demoReadyButton.first
          : fallbackDemoReadyButton.first;
      await tester.ensureVisible(demoReadyFinder);
      await tester.tap(demoReadyFinder);
      await tester.pumpAndSettle();

      final createSiteReadyFinder = find.text('Create Site (Ready)').last;
      await tester.ensureVisible(createSiteReadyFinder);
      await tester.tap(createSiteReadyFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-dispatches'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-operations'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-tactical'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-governance'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-support-open-reports')),
        findsNothing,
      );

      final openScopedDispatchesAction = find.byKey(
        const ValueKey('admin-create-success-support-open-dispatches'),
      );
      await tester.ensureVisible(openScopedDispatchesAction);
      await tester.tap(openScopedDispatchesAction);
      await tester.pumpAndSettle();
      expect(openedDispatchClientId, startsWith('CLT-'));
      expect(openedDispatchSiteId, startsWith('SITE-'));
    },
  );

  testWidgets(
    'build demo stack auto-opens operations when live route is available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? openedOperationsClientId;
      String? openedOperationsSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
            onOpenOperationsForScope: (clientId, siteId) {
              openedOperationsClientId = clientId;
              openedOperationsSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      final buildDemoStackFinder = find.widgetWithText(
        FilledButton,
        'Build Demo Stack',
      );
      await tester.ensureVisible(buildDemoStackFinder.first);
      await tester.tap(buildDemoStackFinder.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (openedOperationsClientId != null &&
            openedOperationsSiteId != null) {
          break;
        }
      }

      expect(openedOperationsClientId, startsWith('DEMO-CLT-'));
      expect(openedOperationsSiteId, startsWith('DEMO-SITE-'));
      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('admin-workspace-command-receipt')),
        findsOneWidget,
      );
      expect(find.text('LIVE ROUTE'), findsOneWidget);
      expect(
        find.textContaining('Operations live route opened with focus:'),
        findsOneWidget,
      );
      expect(
        find.text(
          'The seeded demo route stays pinned in the desktop command rail while Operations opens with the live scope focus.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'build demo stack shows fallback dialog when operations routing is unavailable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? openedDispatchClientId;
      String? openedDispatchSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
            onOpenDispatchesForScope: (clientId, siteId) {
              openedDispatchClientId = clientId;
              openedDispatchSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      final buildDemoStackFinder = find.widgetWithText(
        FilledButton,
        'Build Demo Stack',
      );
      await tester.ensureVisible(buildDemoStackFinder.first);
      await tester.tap(buildDemoStackFinder.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Demo Stack Ready').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-frame')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-header-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-header-status')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-header-chips')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-command')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-create-success-command')),
          matching: find.text(
            'The strongest scoped handoffs stay visible here so the operator can review and route cleanly without losing context.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-command-snapshot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-command-state')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-command-routes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-next-move')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-create-success-next-move')),
          matching: find.text('Review sealed handoff'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-highlights-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-focus-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-focus-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-focus-reference')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-highlights-spotlight')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-highlights-supporting'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-workflow-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-workflow-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-support-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-primary-action')),
        findsOneWidget,
      );
      expect(find.text('Continue to Operations'), findsNothing);
      expect(find.text('Close Checkpoint'), findsOneWidget);
      expect(find.text('SEALED HANDOFFS'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-create-success-header-status')),
          matching: find.text('handoff sealed'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-dispatches'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-operations'),
        ),
        findsNothing,
      );

      final openFallbackDispatchesAction = find.byKey(
        const ValueKey('admin-create-success-support-open-dispatches'),
      );
      await tester.ensureVisible(openFallbackDispatchesAction);
      await tester.tap(openFallbackDispatchesAction);
      await tester.pumpAndSettle();

      expect(openedDispatchClientId, startsWith('DEMO-CLT-'));
      expect(openedDispatchSiteId, startsWith('DEMO-SITE-'));
    },
  );

  testWidgets(
    'build demo stack fallback surfaces the remaining scoped handoff actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? openedGovernanceClientId;
      String? openedGovernanceSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
            onOpenDispatchesForScope: (_, _) {},
            onOpenFleetTacticalScope: (_, _, _) {},
            onOpenGovernanceForScope: (clientId, siteId) {
              openedGovernanceClientId = clientId;
              openedGovernanceSiteId = siteId;
            },
            onOpenClientViewForScope: (_, _) {},
            onOpenReportsForScope: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      final buildDemoStackFinder = find.widgetWithText(
        FilledButton,
        'Build Demo Stack',
      );
      await tester.ensureVisible(buildDemoStackFinder.first);
      await tester.tap(buildDemoStackFinder.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Demo Stack Ready').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-primary-action')),
        findsOneWidget,
      );
      expect(find.text('Continue to Operations'), findsNothing);
      expect(find.text('Close Checkpoint'), findsOneWidget);
      expect(find.text('SEALED HANDOFFS'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-dispatches'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-tactical'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-governance'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-client-view'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-create-success-support-open-reports')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('admin-create-success-support-open-operations'),
        ),
        findsNothing,
      );
      expect(find.text('Open Events'), findsNothing);
      expect(find.text('Open Ledger'), findsNothing);

      final openFallbackGovernanceAction = find.byKey(
        const ValueKey('admin-create-success-support-open-governance'),
      );
      await tester.ensureVisible(openFallbackGovernanceAction);
      await tester.tap(openFallbackGovernanceAction);
      await tester.pump(const Duration(milliseconds: 100));

      expect(openedGovernanceClientId, startsWith('DEMO-CLT-'));
      expect(openedGovernanceSiteId, startsWith('DEMO-SITE-'));
    },
  );

  testWidgets(
    'build demo stack close returns focus to the generated site in sites tab',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      AdministrationPageTab selectedTab = AdministrationPageTab.guards;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
            onTabChanged: (value) => selectedTab = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      final buildDemoStackFinder = find.widgetWithText(
        FilledButton,
        'Build Demo Stack',
      );
      await tester.ensureVisible(buildDemoStackFinder.first);
      await tester.tap(buildDemoStackFinder.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Demo Stack Ready').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsOneWidget,
      );

      final closeSuccessAction = find.byKey(
        const ValueKey('admin-create-success-primary-action'),
      );
      await tester.ensureVisible(closeSuccessAction);
      await tester.tap(closeSuccessAction);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-create-success-title')),
        findsNothing,
      );
      expect(selectedTab, AdministrationPageTab.sites);
      final searchField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(searchField.controller?.text ?? '', startsWith('DEMO-SITE-'));
    },
  );

  testWidgets(
    'reset demo data pins cleanup receipt and clears seeded search focus',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.guards,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Demo Mode'));
      await tapVisibleText(tester, 'Demo Mode');
      await tester.pumpAndSettle();

      final buildDemoStackFinder = find.widgetWithText(
        FilledButton,
        'Build Demo Stack',
      );
      await tester.ensureVisible(buildDemoStackFinder.first);
      await tester.tap(buildDemoStackFinder.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Demo Stack Ready').evaluate().isNotEmpty) {
          break;
        }
      }

      final closeSuccessAction = find.byKey(
        const ValueKey('admin-create-success-primary-action'),
      );
      await tester.ensureVisible(closeSuccessAction);
      await tester.tap(closeSuccessAction);
      await tester.pumpAndSettle();

      final seededSearchField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(
        seededSearchField.controller?.text ?? '',
        startsWith('DEMO-SITE-'),
      );

      final resetButton = find.byKey(const ValueKey('admin-demo-reset-button'));
      expect(find.text('Seal Demo Cleanup'), findsOneWidget);
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-demo-reset-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-demo-reset-status')),
        findsOneWidget,
      );
      expect(find.text('DEMO CLEANUP'), findsOneWidget);
      expect(
        find.text(
          'Seal cleanup and return the storyboard to an unseeded state.',
        ),
        findsOneWidget,
      );
      expect(find.text('Hold State'), findsOneWidget);

      final confirmResetButton = find.byKey(
        const ValueKey('admin-demo-reset-confirm-button'),
      );
      await tester.ensureVisible(confirmResetButton);
      await tester.tap(confirmResetButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text('DEMO CLEANUP'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(
            'Demo data cleared: 1 client(s), 1 site(s), 1 employee(s).',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(
            'The cleanup result stays pinned in the desktop command rail while the storyboard returns to an unseeded state.',
          ),
        ),
        findsOneWidget,
      );

      final clearedSearchField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(clearedSearchField.controller?.text ?? '', isEmpty);
    },
  );

  testWidgets('system tab shows ops poll health rows when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          radioOpsPollHealth: 'ok 3 • fail 1 • skip 0 • last 10:05:00 UTC',
          radioOpsQueueHealth:
              'pending 4 • due 1 • deferred 3 • max-attempt 2 • next 10:05:30 UTC',
          radioOpsQueueIntentMix:
              'pending intent mix • all_clear 2 • panic 1 • duress 1 • status 0 • unknown 0',
          radioOpsAckRecentSummary:
              'recent ack 5 (6h) • all_clear 2 • panic 1 • duress 1 • status 1',
          radioOpsQueueStateDetail: 'Queue updated via ingest • 10:06:20 UTC',
          radioOpsFailureDetail:
              'Last failure • ZEL-9001 • reason send_failed • count 2 • at 10:05:30 UTC',
          radioOpsFailureAuditDetail: 'Failure snapshot cleared • 10:06:00 UTC',
          radioOpsManualActionDetail:
              'Retry requested for 4 queued • 10:05:15 UTC',
          cctvOpsPollHealth: 'ok 2 • fail 0 • skip 0 • last 10:05:01 UTC',
          cctvCapabilitySummary: 'caps LIVE AI MONITORING • FR • LPR',
          cctvRecentSignalSummary:
              'recent video intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 1 • lpr 2',
          cctvEvidenceHealthSummary:
              'verified 2 • fail 0 • dropped 0 • queue 2/12 • last 10:05:01 UTC',
          cctvCameraHealthSummary:
              'front-gate:healthy • zone north_gate • stale 1m | yard:stale • zone driveway • stale 42m',
          incidentSpoolHealthSummary:
              'buffering • 3 pending • retry 1 • queued 2026-03-13T10:05:30.000Z',
          incidentSpoolReplaySummary:
              '2 replayed • client_ledger • last INC-002 • 2026-03-13T10:07:00.000Z',
          monitoringWatchAuditSummary:
              'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-13T10:08:00.000Z',
          monitoringWatchAuditHistory: <String>[
            'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-13T10:08:00.000Z',
            'Resync • DISPATCH • MS Vallee Residence • Already aligned • 2026-03-13T09:58:00.000Z',
          ],
          wearableOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:02 UTC',
          newsOpsPollHealth: 'ok 4 • fail 0 • skip 0 • last 10:05:03 UTC',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    expect(find.text('Ops Integration Poll Health'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-ops-poll-command')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-ops-poll-focus-board')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-ops-poll-focus-pivot-video')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-ops-poll-focus-entry-radio-queue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-ops-poll-row-radio-queue')),
      findsOneWidget,
    );
    expect(find.textContaining('ok 3 • fail 1'), findsOneWidget);
    expect(find.textContaining('pending 4 • due 1 • deferred 3'), findsWidgets);
    expect(
      find.textContaining('pending intent mix • all_clear 2 • panic 1'),
      findsWidgets,
    );
    expect(
      find.textContaining('recent ack 5 (6h) • all_clear 2 • panic 1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Queue updated via ingest • 10:06:20 UTC'),
      findsWidgets,
    );
    expect(find.textContaining('Last failure • ZEL-9001'), findsWidgets);
    expect(
      find.textContaining('Failure snapshot cleared • 10:06:00 UTC'),
      findsOneWidget,
    );
    expect(find.textContaining('Retry requested for 4 queued'), findsOneWidget);
    expect(find.textContaining('ok 2 • fail 0'), findsOneWidget);
    expect(
      find.textContaining('LIVE AI MONITORING • FR • LPR'),
      findsOneWidget,
    );
    expect(
      find.textContaining('recent video intel 5 (6h) • intrusion 2'),
      findsOneWidget,
    );
    expect(
      find.textContaining('verified 2 • fail 0 • dropped 0 • queue 2/12'),
      findsOneWidget,
    );
    expect(
      find.textContaining('front-gate:healthy • zone north_gate'),
      findsOneWidget,
    );
    expect(
      find.textContaining('buffering • 3 pending • retry 1'),
      findsOneWidget,
    );
    expect(find.textContaining('2 replayed • client_ledger'), findsOneWidget);
    expect(find.text('Watch Recovery Trail'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-watch-audit-command')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-watch-audit-open-latest')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-watch-audit-open-previous')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-watch-audit-copy-record')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-13T10:08:00.000Z',
      ),
      findsOneWidget,
    );
    expect(find.text('MS Vallee Residence'), findsWidgets);
    expect(find.text('Actor ADMIN'), findsWidgets);
    expect(find.text('Actor DISPATCH'), findsOneWidget);
    expect(find.text('Outcome Resynced'), findsWidgets);
    expect(find.text('Outcome Already aligned'), findsOneWidget);
    expect(find.text('At 2026-03-13 10:08 UTC'), findsWidgets);
    expect(find.text('At 2026-03-13 09:58 UTC'), findsOneWidget);
    expect(find.textContaining('ok 1 • fail 0'), findsOneWidget);
    expect(find.textContaining('ok 4 • fail 0'), findsOneWidget);
  });

  testWidgets(
    'system tab ops poll command pins desktop receipt for radio queue actions',
    (tester) async {
      var runOpsPollCalls = 0;
      var runRadioPollCalls = 0;
      var retryCalls = 0;
      tester.view.physicalSize = const Size(1680, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            radioOpsPollHealth: 'ok 3 • fail 1 • skip 0 • last 10:05:00 UTC',
            radioOpsQueueHealth:
                'pending 4 • due 1 • deferred 3 • max-attempt 2 • next 10:05:30 UTC',
            radioOpsFailureDetail:
                'Last failure • ZEL-9001 • reason send_failed • count 2 • at 10:05:30 UTC',
            radioQueueHasPending: true,
            onRunOpsIntegrationPoll: () async {
              runOpsPollCalls += 1;
            },
            onRunRadioPoll: () async {
              runRadioPollCalls += 1;
            },
            onRetryRadioQueue: () async {
              retryCalls += 1;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-ops-poll-row-radio')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-ops-poll-row-radio')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-ops-poll-next-move')),
          matching: find.text('Poll radio'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-ops-poll-focus-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-ops-poll-focus-entry-radio')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('admin-ops-poll-command-poll-radio')),
      );
      await tester.pumpAndSettle();

      expect(runRadioPollCalls, 1);
      expect(find.text('Polled radio telemetry.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('admin-ops-poll-focus-pivot-queue')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focused queue lane.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-ops-poll-next-move')),
          matching: find.text('Retry queue'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-ops-poll-focus-entry-radio-queue')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('admin-ops-poll-command-retry-queue')),
      );
      await tester.pumpAndSettle();

      expect(retryCalls, 1);
      expect(find.text('Retried queued radio actions.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('admin-ops-poll-command-run-ops')),
      );
      await tester.pumpAndSettle();

      expect(runOpsPollCalls, 1);
      expect(find.text('Ran ops integration poll.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'system tab watch recovery command pins desktop receipt and scoped actions',
    (tester) async {
      String? copiedPayload;
      String? openedGovernanceClientId;
      String? openedGovernanceSiteId;
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
      tester.view.physicalSize = const Size(1680, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            monitoringWatchAuditSummary:
                'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-13T10:08:00.000Z',
            monitoringWatchAuditHistory: const <String>[
              'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-13T10:08:00.000Z',
              'Resync • DISPATCH • MS Vallee Residence • Already aligned • 2026-03-13T09:58:00.000Z',
            ],
            onOpenGovernanceForScope: (clientId, siteId) {
              openedGovernanceClientId = clientId;
              openedGovernanceSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-ops-poll-watch-audit-row')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('admin-ops-poll-watch-audit-row')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focused the watch recovery trail.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-watch-audit-command')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('admin-watch-audit-open-previous')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-watch-audit-next-move')),
          matching: find.text('Return latest'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('admin-watch-audit-copy-record')),
      );
      await tester.pumpAndSettle();

      expect(
        copiedPayload,
        'Resync • DISPATCH • MS Vallee Residence • Already aligned • 2026-03-13T09:58:00.000Z',
      );
      expect(
        find.byKey(const ValueKey('admin-workspace-command-receipt')),
        findsOneWidget,
      );
      expect(
        find.text('Watch audit copied for MS Vallee Residence.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('admin-watch-audit-open-governance')),
      );
      await tester.pumpAndSettle();

      expect(openedGovernanceClientId, 'CLIENT-MS-VALLEE');
      expect(openedGovernanceSiteId, 'SITE-MS-VALLEE-RESIDENCE');
      expect(
        find.text('Opened watch recovery governance for MS Vallee Residence.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'system tab shows listener alarm summary card from audit events',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            supabaseReady: false,
            events: <DispatchEvent>[
              ListenerAlarmFeedCycleRecorded(
                eventId: 'alarm-cycle-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 16, 8, 0),
                sourceLabel: 'listener-http',
                acceptedCount: 5,
                mappedCount: 4,
                unmappedCount: 1,
                duplicateCount: 0,
                rejectedCount: 0,
                normalizationSkippedCount: 0,
                deliveredCount: 4,
                failedCount: 0,
                clearCount: 3,
                suspiciousCount: 1,
                unavailableCount: 0,
                pendingCount: 0,
                rejectSummary: '',
              ),
              ListenerAlarmAdvisoryRecorded(
                eventId: 'alarm-advisory-1',
                sequence: 2,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 16, 8, 1),
                clientId: 'CLIENT-1',
                regionId: 'REGION-1',
                siteId: 'VALLEE',
                externalAlarmId: 'EXT-1',
                accountNumber: '1234',
                partition: '1',
                zone: '004',
                zoneLabel: 'Front gate',
                eventLabel: 'Burglary',
                dispositionLabel: 'suspicious',
                summary: 'Person detected near the front gate camera.',
                recommendation: 'Escalation recommended.',
                deliveredCount: 1,
                failedCount: 0,
              ),
              ListenerAlarmParityCycleRecorded(
                eventId: 'alarm-parity-1',
                sequence: 3,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 16, 8, 2),
                sourceLabel: 'listener-http',
                legacySourceLabel: 'oryx-http',
                statusLabel: 'ok',
                serialCount: 5,
                legacyCount: 5,
                matchedCount: 4,
                unmatchedSerialCount: 1,
                unmatchedLegacyCount: 1,
                maxAllowedSkewSeconds: 90,
                maxSkewSecondsObserved: 22,
                averageSkewSeconds: 8.4,
                driftSummary: 'serial 5 • legacy 5 • matched 4',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, 'System');
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-listener-alarm-command')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-listener-alarm-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-listener-alarm-row-feed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-listener-alarm-row-advisory')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-listener-alarm-row-parity')),
        findsOneWidget,
      );
      expect(find.textContaining('Cycles'), findsOneWidget);
      expect(find.textContaining('Advisories'), findsOneWidget);
      expect(
        find.textContaining('Latest cycle • mapped 4/5 • missed 1'),
        findsWidgets,
      );
      expect(
        find.textContaining('Latest advisory • VALLEE • Burglary'),
        findsWidgets,
      );
      expect(
        find.textContaining('OK • matched 4/5 • serial-only 1 • legacy-only 1'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'system tab listener alarm command pins desktop receipt and scoped governance',
    (tester) async {
      String? copiedPayload;
      String? openedGovernanceClientId;
      String? openedGovernanceSiteId;
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
      tester.view.physicalSize = const Size(1680, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            listenerAlarmOpsPollHealth:
                'ok 4 • fail 0 • skip 0 • last 08:02:00 UTC',
            events: <DispatchEvent>[
              ListenerAlarmFeedCycleRecorded(
                eventId: 'alarm-cycle-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 16, 8, 0),
                sourceLabel: 'listener-http',
                acceptedCount: 5,
                mappedCount: 4,
                unmappedCount: 1,
                duplicateCount: 0,
                rejectedCount: 0,
                normalizationSkippedCount: 0,
                deliveredCount: 4,
                failedCount: 0,
                clearCount: 3,
                suspiciousCount: 1,
                unavailableCount: 0,
                pendingCount: 0,
                rejectSummary: '',
              ),
              ListenerAlarmAdvisoryRecorded(
                eventId: 'alarm-advisory-1',
                sequence: 2,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 16, 8, 1),
                clientId: 'CLIENT-MS-VALLEE',
                regionId: 'REGION-1',
                siteId: 'VALLEE',
                externalAlarmId: 'EXT-1',
                accountNumber: '1234',
                partition: '1',
                zone: '004',
                zoneLabel: 'Front gate',
                eventLabel: 'Burglary',
                dispositionLabel: 'suspicious',
                summary: 'Person detected near the front gate camera.',
                recommendation: 'Escalation recommended.',
                deliveredCount: 1,
                failedCount: 0,
              ),
              ListenerAlarmParityCycleRecorded(
                eventId: 'alarm-parity-1',
                sequence: 3,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 16, 8, 2),
                sourceLabel: 'listener-http',
                legacySourceLabel: 'oryx-http',
                statusLabel: 'ok',
                serialCount: 5,
                legacyCount: 5,
                matchedCount: 4,
                unmatchedSerialCount: 1,
                unmatchedLegacyCount: 1,
                maxAllowedSkewSeconds: 90,
                maxSkewSecondsObserved: 22,
                averageSkewSeconds: 8.4,
                driftSummary: 'serial 5 • legacy 5 • matched 4',
              ),
            ],
            onOpenGovernanceForScope: (clientId, siteId) {
              openedGovernanceClientId = clientId;
              openedGovernanceSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-ops-poll-listener-alarm-row')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('admin-ops-poll-listener-alarm-row')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focused listener alarm command.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-listener-alarm-command')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('admin-listener-alarm-copy-snapshot')),
      );
      await tester.pumpAndSettle();

      expect(copiedPayload, contains('Latest advisory • VALLEE • Burglary'));
      expect(
        find.textContaining(
          'Listener advisory lane copied for command review.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('admin-listener-alarm-open-governance')),
      );
      await tester.pumpAndSettle();

      expect(openedGovernanceClientId, 'CLIENT-MS-VALLEE');
      expect(openedGovernanceSiteId, 'SITE-MS-VALLEE-RESIDENCE');
      expect(
        find.text('Opened listener governance for MS Vallee Residence.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('system tab shows global readiness summary card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-1',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 16, 22, 0),
              intelligenceId: 'intel-1',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-1',
              clientId: 'CLIENT-1',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
              cameraId: 'gate-cam',
              faceMatchId: 'PERSON-44',
              objectLabel: 'person',
              objectConfidence: 0.95,
              headline: 'HIKVISION ALERT',
              summary: 'Boundary activity detected',
              riskScore: 93,
              snapshotUrl: 'https://edge.example.com/intel-1.jpg',
              canonicalHash: 'hash-1',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'intel-1': MonitoringSceneReviewRecord(
              intelligenceId: 'intel-1',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'boundary identity concern',
              decisionLabel: 'Escalation Candidate',
              decisionSummary: 'Escalation posture requires response review.',
              summary: 'Boundary activity at gate.',
              reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 1),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-global-readiness-card')),
      findsOneWidget,
    );
    expect(find.text('Global Readiness'), findsOneWidget);
    expect(find.textContaining('Latest intent'), findsOneWidget);
    expect(find.textContaining('Simulation'), findsOneWidget);
  });

  testWidgets('system tab highlights hazard playbook and rehearsal summaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          events: <DispatchEvent>[
            IntelligenceReceived(
              eventId: 'evt-fire',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 16, 22, 0),
              intelligenceId: 'intel-fire',
              provider: 'hikvision_dvr_monitor_only',
              sourceType: 'dvr',
              externalId: 'ext-fire',
              clientId: 'CLIENT-1',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
              cameraId: 'generator-room-cam',
              objectLabel: 'smoke',
              objectConfidence: 0.95,
              headline: 'HIKVISION FIRE ALERT',
              summary: 'Smoke visible in the generator room.',
              riskScore: 93,
              snapshotUrl: 'https://edge.example.com/intel-fire.jpg',
              canonicalHash: 'hash-fire',
            ),
          ],
          sceneReviewByIntelligenceId: {
            'intel-fire': MonitoringSceneReviewRecord(
              intelligenceId: 'intel-fire',
              sourceLabel: 'openai:gpt-5.4-mini',
              postureLabel: 'fire and smoke emergency',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalation posture requires fire response review.',
              summary: 'Smoke plume visible inside the generator room.',
              reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 1),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Fire playbook active'), findsWidgets);
    expect(find.textContaining('Fire rehearsal recommended'), findsOneWidget);
    expect(
      find.textContaining(
        'Learned bias: stage fire response one step earlier next shift.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('system tab shows video integrity certificate preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          videoOpsLabel: 'DVR',
          videoIntegrityCertificateStatus: 'PASS',
          videoIntegrityCertificateSummary:
              'Bundle hash sealed for dvr validation_report.json.',
          videoIntegrityCertificateJsonPreview:
              '{\n  "status": "PASS",\n  "bundle_hash": "abc123"\n}',
          videoIntegrityCertificateMarkdownPreview:
              '# Integrity Certificate\n\n- Status: `PASS`\n- Bundle hash: `abc123`',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    expect(find.text('DVR Integrity Certificate'), findsOneWidget);
    expect(
      find.textContaining('Bundle hash sealed for dvr validation_report.json.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('View Certificate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Certificate'));
    await tester.pumpAndSettle();

    expect(find.text('DVR Integrity Certificate'), findsAtLeastNWidgets(1));
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.textContaining('"bundle_hash": "abc123"'), findsOneWidget);
    expect(find.text('Copy JSON'), findsOneWidget);
    expect(find.text('Copy Markdown'), findsOneWidget);
  });

  testWidgets('system tab validates and saves radio intent dictionary', (
    tester,
  ) async {
    String? savedRaw;
    var resetCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialRadioIntentPhrasesJson:
              '{"all_clear":["all clear"],"panic":["panic"],"duress":["silent duress"],"status":["status update"]}',
          onSaveRadioIntentPhrasesJson: (rawJson) async {
            savedRaw = rawJson;
          },
          onResetRadioIntentPhrasesJson: () async {
            resetCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    expect(find.text('Radio Intent Dictionary'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-radio-intent-command')),
      findsOneWidget,
    );
    final radioEditor = find.byWidgetPredicate((widget) {
      if (widget is! TextField) return false;
      final hint = widget.decoration?.hintText ?? '';
      return hint.contains('"panic button"');
    });
    final radioValidateButton = find.text('Validate').first;
    final radioSaveButton = find.text('Save Runtime').first;
    final radioResetButton = find.text('Reset To Defaults').first;
    expect(radioEditor, findsOneWidget);
    expect(radioValidateButton, findsOneWidget);
    expect(radioSaveButton, findsOneWidget);
    expect(radioResetButton, findsOneWidget);

    await tester.enterText(radioEditor, '{not-json');
    await tester.ensureVisible(radioValidateButton);
    await tester.pumpAndSettle();
    await tester.tap(radioValidateButton);
    await tester.pumpAndSettle();
    expect(savedRaw, isNull);

    await tester.enterText(
      radioEditor,
      '{"all_clear":["all clear"],"panic":["panic button"],"duress":["duress"],"status":["status check"]}',
    );
    await tester.ensureVisible(radioSaveButton);
    await tester.pumpAndSettle();
    await tester.tap(radioSaveButton);
    await tester.pumpAndSettle();

    expect(savedRaw, contains('"panic button"'));

    await tester.ensureVisible(radioResetButton);
    await tester.pumpAndSettle();
    await tester.tap(radioResetButton);
    await tester.pumpAndSettle();
    expect(resetCalls, 1);
  });

  testWidgets('system tab invokes radio queue action callbacks', (
    tester,
  ) async {
    var runOpsPollCalls = 0;
    var runRadioPollCalls = 0;
    var runCctvPollCalls = 0;
    var runWearablePollCalls = 0;
    var runNewsPollCalls = 0;
    var retryCalls = 0;
    var clearCalls = 0;
    var clearFailureSnapshotCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          videoOpsLabel: 'DVR',
          radioOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:00 UTC',
          radioOpsQueueHealth: 'pending 2 • due 1 • deferred 1 • max-attempt 2',
          radioOpsFailureDetail:
              'Last failure • ZEL-9001 • reason send_failed • count 2 • at 10:05:30 UTC',
          radioQueueHasPending: true,
          onRunOpsIntegrationPoll: () async {
            runOpsPollCalls += 1;
          },
          onRunRadioPoll: () async {
            runRadioPollCalls += 1;
          },
          onRunCctvPoll: () async {
            runCctvPollCalls += 1;
          },
          onRunWearablePoll: () async {
            runWearablePollCalls += 1;
          },
          onRunNewsPoll: () async {
            runNewsPollCalls += 1;
          },
          onRetryRadioQueue: () async {
            retryCalls += 1;
          },
          onClearRadioQueue: () async {
            clearCalls += 1;
          },
          onClearRadioQueueFailureSnapshot: () async {
            clearFailureSnapshotCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-ops-recovery-deck')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-run-ops')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-ops-recovery-run-ops')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-run-radio')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-ops-recovery-run-radio')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-run-video')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-ops-recovery-run-video')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-run-wearable')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-ops-recovery-run-wearable')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-run-news')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-ops-recovery-run-news')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-retry-queue')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-ops-recovery-retry-queue')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-clear-queue')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-ops-recovery-clear-queue')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear Radio Queue?'), findsOneWidget);
    await tester.tap(find.text('Confirm Clear').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-clear-failure')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-ops-recovery-clear-failure')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear Last Failure Snapshot?'), findsOneWidget);
    await tester.tap(find.text('Confirm Clear').first);
    await tester.pumpAndSettle();

    expect(runOpsPollCalls, 1);
    expect(runRadioPollCalls, 1);
    expect(runCctvPollCalls, 1);
    expect(runWearablePollCalls, 1);
    expect(runNewsPollCalls, 1);
    expect(retryCalls, 1);
    expect(clearCalls, 1);
    expect(clearFailureSnapshotCalls, 1);
  });

  testWidgets(
    'system tab stages runtime config drafts when persistence hooks are absent',
    (tester) async {
      String? copiedPayload;
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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

      await tester.pumpWidget(
        const MaterialApp(
          home: AdministrationPage(
            events: <DispatchEvent>[],
            supabaseReady: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, 'System');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-radio-intent-command')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-demo-route-command')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('radio-intent-save-runtime')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('radio-intent-reset-runtime')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('demo-route-save-runtime')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('demo-route-reset-runtime')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('radio-intent-save-runtime')),
      );
      await tester.tap(find.byKey(const ValueKey('radio-intent-save-runtime')));
      await tester.pumpAndSettle();

      expect(copiedPayload, contains('Editor: Radio Intent Dictionary'));
      expect(copiedPayload, contains('State: defaults-active'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(
            'Radio intent runtime draft copied for command review.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('system tab clear radio queue cancel does not invoke callback', (
    tester,
  ) async {
    var clearCalls = 0;
    var clearFailureSnapshotCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          radioOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:00 UTC',
          radioOpsQueueHealth: 'pending 1 • due 1 • deferred 0 • max-attempt 1',
          radioOpsFailureDetail:
              'Last failure • ZEL-9001 • reason send_failed • count 1 • at 10:05:30 UTC',
          radioQueueHasPending: true,
          onClearRadioQueue: () async {
            clearCalls += 1;
          },
          onClearRadioQueueFailureSnapshot: () async {
            clearFailureSnapshotCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-clear-queue')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-ops-recovery-clear-queue')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear Radio Queue?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-ops-recovery-clear-failure')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-ops-recovery-clear-failure')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear Last Failure Snapshot?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    expect(clearCalls, 0);
    expect(clearFailureSnapshotCalls, 0);
  });

  testWidgets('system tab groups fleet scopes into actionable and watch-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          cctvOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:01 UTC',
          fleetScopeHealth: <VideoFleetScopeHealthView>[
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 2,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              watchWindowLabel: '18:00-06:00',
              watchWindowStateLabel: 'IN WINDOW',
              alertCount: 1,
              escalationCount: 1,
              actionHistory: [
                '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
              ],
              latestEventLabel: 'Vehicle motion',
              latestIncidentReference: 'INT-VALLEE-1',
              latestEventTimeLabel: '21:14 UTC',
              latestCameraLabel: 'Camera 1',
              latestRiskScore: 84,
              latestFaceMatchId: 'PERSON-44',
              latestFaceConfidence: 91.2,
              latestPlateNumber: 'CA123456',
              latestPlateConfidence: 96.4,
              latestSceneReviewLabel:
                  'openai:gpt-4.1-mini • identity match concern • 21:14 UTC',
              latestSceneDecisionSummary:
                  'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 0,
              lastSeenLabel: 'idle',
              freshnessLabel: 'Idle',
              isStale: false,
              watchWindowLabel: '18:00-06:00',
              watchWindowStateLabel: 'IN WINDOW',
              repeatCount: 2,
              suppressedCount: 3,
              lastRecoveryLabel: 'ADMIN • Resynced • 21:08 UTC',
              latestSceneDecisionLabel: 'Suppressed',
              latestSceneDecisionSummary:
                  'Suppressed because the activity remained below the client notification threshold.',
              watchActivationGapLabel: 'MISSED START',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    expect(
      find.text('ACTIONABLE (1) • Incident-backed fleet scopes'),
      findsOneWidget,
    );
    expect(
      find.text('WATCH-ONLY (1) • Watch scopes awaiting incident context'),
      findsOneWidget,
    );
    expect(find.text('Gap 1'), findsOneWidget);
    expect(find.text('Recovered 6h 1'), findsOneWidget);
    expect(find.text('Suppressed 1'), findsOneWidget);
    expect(
      find.textContaining('Identity policy: Flagged match'),
      findsOneWidget,
    );
    expect(find.text('Identity Flagged'), findsOneWidget);
    expect(
      find.textContaining(
        'Identity match: Face PERSON-44 91.2% • Plate CA123456 96.4%',
      ),
      findsOneWidget,
    );
    expect(find.text('Alerts 1'), findsOneWidget);
    expect(find.text('Repeat 2'), findsOneWidget);
    expect(find.text('Escalated 1'), findsOneWidget);
    expect(find.text('Filtered 3'), findsOneWidget);
    expect(find.text('Flagged ID 1'), findsOneWidget);
    expect(find.text('Allowed ID 0'), findsOneWidget);
    expect(find.text('Recovery ADMIN • Resynced • 21:08 UTC'), findsOneWidget);
    expect(find.text('Window 18:00-06:00'), findsNWidgets(2));
    expect(find.text('Phase IN WINDOW'), findsNWidgets(2));
    expect(find.text('Gap MISSED START'), findsOneWidget);

    await tester.ensureVisible(find.text('Alerts 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alerts 1'));
    await tester.pumpAndSettle();
    expect(find.text('Focused watch action: Alert actions'), findsOneWidget);
    expect(
      find.text('Showing fleet scopes where ONYX sent a client alert.'),
      findsOneWidget,
    );
    expect(
      find.text('ACTIONABLE (1) • Incident-backed alert scopes'),
      findsOneWidget,
    );
    expect(
      find.text(
        'WATCH-ONLY (0) • No watch-only alert scopes awaiting incident context',
      ),
      findsOneWidget,
    );
    expect(find.text('Beta Watch'), findsNothing);

    await tester.ensureVisible(find.text('Escalated 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escalated 1'));
    await tester.pumpAndSettle();
    expect(
      find.text('Focused watch action: Escalated reviews'),
      findsOneWidget,
    );
    final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(
      textWidgets.indexWhere((widget) => widget.data == 'CCTV Fleet Health'),
      lessThan(
        textWidgets.indexWhere((widget) => widget.data == 'Guard Roster'),
      ),
    );
    expect(find.text('Beta Watch'), findsNothing);
    expect(find.text('MS Vallee Residence'), findsOneWidget);
    expect(
      find.textContaining(
        'Recent action: 21:13 UTC • Camera 2 • Monitoring Alert',
      ),
      findsWidgets,
    );
    expect(find.text('Latest: 21:14 UTC • Vehicle motion'), findsNothing);
  });

  testWidgets('system tab shows configured identity rules panel', (
    tester,
  ) async {
    final identityPolicyService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          monitoringIdentityPolicyService: identityPolicyService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    expect(find.text('Identity Rules'), findsOneWidget);
    expect(find.text('1 sites'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('identity-rules-focus-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('identity-rules-focus-site-SITE-MS-VALLEE-RESIDENCE'),
      ),
      findsOneWidget,
    );
    expect(find.text('SITE-MS-VALLEE-RESIDENCE'), findsWidgets);
    expect(find.text('CLIENT-MS-VALLEE'), findsWidgets);
    expect(find.text('Flagged faces 1'), findsOneWidget);
    expect(find.text('Flagged plates 1'), findsOneWidget);
    expect(find.text('Allowed faces 1'), findsOneWidget);
    expect(find.text('Allowed plates 1'), findsOneWidget);
    expect(find.text('PERSON-44'), findsOneWidget);
    expect(find.text('CA123456'), findsOneWidget);
    expect(find.text('RESIDENT-01'), findsOneWidget);
    expect(find.text('CA111111'), findsOneWidget);
  });

  testWidgets('system tab identity rules focus board pivots selected site', (
    tester,
  ) async {
    final identityPolicyService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]},{"client_id":"CLIENT-BETA","site_id":"SITE-BETA","flagged_face_match_ids":["PERSON-99"]}]',
    );
    String? copiedPayload;
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          monitoringIdentityPolicyService: identityPolicyService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    final focusCard = find.byKey(const ValueKey('identity-rules-focus-card'));
    expect(focusCard, findsOneWidget);
    expect(
      find.descendant(
        of: focusCard,
        matching: find.text('SITE-MS-VALLEE-RESIDENCE'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('identity-rules-focus-site-SITE-BETA')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('identity-rules-focus-site-SITE-BETA')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('identity-rules-entry-selected-SITE-BETA')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('identity-rules-focus-next-move')),
        matching: find.text('Review flagged rules'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('identity-rules-focus-copy-site')),
    );
    await tester.pumpAndSettle();

    expect(copiedPayload, contains('CLIENT-BETA'));
    expect(copiedPayload, contains('SITE-BETA'));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
        matching: find.text('Site identity rules JSON copied for SITE-BETA.'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'system tab stages identity rules runtime actions when persistence hooks are absent',
    (tester) async {
      final identityPolicyService = MonitoringIdentityPolicyService.parseJson(
        '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
      );
      String? copiedPayload;
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            monitoringIdentityPolicyService: identityPolicyService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, 'System');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('identity-rules-save-runtime')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('identity-rules-reset-runtime')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('identity-rules-save-runtime')),
      );
      await tester.tap(
        find.byKey(const ValueKey('identity-rules-save-runtime')),
      );
      await tester.pumpAndSettle();

      expect(copiedPayload, contains('Editor: Identity Rules Runtime'));
      expect(copiedPayload, contains('CLIENT-MS-VALLEE'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(
            'Identity rules runtime draft copied for command review.',
          ),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('identity-rules-reset-runtime')),
      );
      await tester.tap(
        find.byKey(const ValueKey('identity-rules-reset-runtime')),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 sites'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text('Identity rules reset to local defaults.'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'system tab persists watch action drilldown through parent-owned remounts',
    (tester) async {
      VideoFleetWatchActionDrilldown? selectedDrilldown =
          VideoFleetWatchActionDrilldown.limited;
      var showAdmin = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAdmin = !showAdmin;
                      });
                    },
                    child: const Text('Toggle admin'),
                  ),
                  Expanded(
                    child: showAdmin
                        ? AdministrationPage(
                            events: const <DispatchEvent>[],
                            supabaseReady: false,
                            initialTab: AdministrationPageTab.system,
                            initialWatchActionDrilldown: selectedDrilldown,
                            onWatchActionDrilldownChanged: (value) {
                              setState(() {
                                selectedDrilldown = value;
                              });
                            },
                            cctvOpsPollHealth:
                                'ok 1 • fail 0 • skip 0 • last 10:05:01 UTC',
                            fleetScopeHealth: const <VideoFleetScopeHealthView>[
                              VideoFleetScopeHealthView(
                                clientId: 'CLIENT-B',
                                siteId: 'SITE-B',
                                siteName: 'Beta Watch',
                                endpointLabel: '192.168.8.106',
                                statusLabel: 'LIMITED WATCH',
                                watchLabel: 'LIMITED',
                                recentEvents: 0,
                                lastSeenLabel: '21:14 UTC',
                                freshnessLabel: 'Recent',
                                isStale: false,
                                monitoringAvailabilityDetail:
                                    'One remote camera feed is stale.',
                                latestIncidentReference: 'INT-BETA-1',
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsOneWidget,
      );
      expect(
        find.text('ACTIONABLE (1) • Incident-backed limited-watch scopes'),
        findsOneWidget,
      );

      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsOneWidget,
      );
      expect(
        find.text('ACTIONABLE (1) • Incident-backed limited-watch scopes'),
        findsOneWidget,
      );
    },
  );

  testWidgets('system tab can add and remove identity rule values', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    changedService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: changedService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  changedService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    final addRuleButton = find.byKey(
      const ValueKey('identity-rule-add-flaggedFaces-SITE-MS-VALLEE-RESIDENCE'),
    );
    await tester.ensureVisible(addRuleButton);
    await tester.tap(addRuleButton);
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'person-77');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Flagged faces 2'), findsOneWidget);
    expect(find.text('PERSON-77'), findsOneWidget);
    expect(
      changedService
          .policyFor(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          )
          .flaggedFaceMatchIds,
      contains('PERSON-77'),
    );

    await tester.tap(find.byTooltip('Remove PERSON-44'));
    await tester.pumpAndSettle();

    expect(find.text('Flagged faces 1'), findsOneWidget);
    expect(find.text('PERSON-44'), findsNothing);
    expect(
      changedService
          .policyFor(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          )
          .flaggedFaceMatchIds,
      isNot(contains('PERSON-44')),
    );
  });

  testWidgets('system tab shows recent identity rule changes', (tester) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    final addRuleButton = find.byKey(
      const ValueKey('identity-rule-add-flaggedFaces-SITE-MS-VALLEE-RESIDENCE'),
    );
    await tester.ensureVisible(addRuleButton);
    await tester.tap(addRuleButton);
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'person-77');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pump();

    expect(find.text('Recent Rule Changes'), findsOneWidget);
    expect(find.text('1 recent'), findsOneWidget);
    expect(find.text('Manual edit'), findsWidgets);
    expect(
      find.textContaining(
        'Added PERSON-77 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('system tab can start with persisted identity rule history', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          monitoringIdentityPolicyService:
              const MonitoringIdentityPolicyService(
                policiesByScope: {
                  'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE':
                      MonitoringIdentityScopePolicy(
                        flaggedFaceMatchIds: {'PERSON-44'},
                      ),
                },
              ),
          initialMonitoringIdentityRuleAuditHistory:
              <MonitoringIdentityPolicyAuditRecord>[
                MonitoringIdentityPolicyAuditRecord(
                  recordedAtUtc: DateTime.utc(2026, 3, 15, 7, 14),
                  source: MonitoringIdentityPolicyAuditSource.manualEdit,
                  message:
                      'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
                ),
              ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    expect(find.text('Recent Rule Changes'), findsOneWidget);
    expect(find.text('1 recent'), findsOneWidget);
    expect(find.text('Manual edit'), findsWidgets);
    expect(find.text('2026-03-15 07:14 UTC'), findsOneWidget);
    expect(
      find.textContaining(
        'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('system tab can filter identity rule history by source', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          monitoringIdentityPolicyService:
              const MonitoringIdentityPolicyService(
                policiesByScope: {
                  'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE':
                      MonitoringIdentityScopePolicy(
                        flaggedFaceMatchIds: {'PERSON-44'},
                      ),
                },
              ),
          initialMonitoringIdentityRuleAuditHistory:
              <MonitoringIdentityPolicyAuditRecord>[
                MonitoringIdentityPolicyAuditRecord(
                  recordedAtUtc: DateTime.utc(2026, 3, 15, 7, 14),
                  source: MonitoringIdentityPolicyAuditSource.manualEdit,
                  message:
                      'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
                ),
                MonitoringIdentityPolicyAuditRecord(
                  recordedAtUtc: DateTime.utc(2026, 3, 15, 7, 10),
                  source: MonitoringIdentityPolicyAuditSource.saveRuntime,
                  message: 'Saved runtime identity rules (1 sites).',
                ),
              ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    expect(find.text('2 recent'), findsOneWidget);
    expect(find.text('Manual edit'), findsWidgets);
    expect(find.text('Runtime save'), findsWidgets);

    final manualEditFilter = find.byKey(
      const ValueKey('identity-audit-filter-manual_edit'),
    );
    await tester.ensureVisible(manualEditFilter);
    await tester.tap(manualEditFilter);
    await tester.pumpAndSettle();

    expect(find.text('1 recent'), findsOneWidget);
    expect(
      find.textContaining(
        'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Saved runtime identity rules (1 sites).'),
      findsNothing,
    );
  });

  testWidgets(
    'system tab persists identity rule history filter through parent-owned remounts',
    (tester) async {
      MonitoringIdentityPolicyAuditSource? selectedSource =
          MonitoringIdentityPolicyAuditSource.manualEdit;
      var showAdmin = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAdmin = !showAdmin;
                      });
                    },
                    child: const Text('Toggle admin'),
                  ),
                  Expanded(
                    child: showAdmin
                        ? AdministrationPage(
                            events: const <DispatchEvent>[],
                            supabaseReady: false,
                            initialTab: AdministrationPageTab.system,
                            monitoringIdentityPolicyService:
                                const MonitoringIdentityPolicyService(
                                  policiesByScope: {
                                    'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE':
                                        MonitoringIdentityScopePolicy(
                                          flaggedFaceMatchIds: {'PERSON-44'},
                                        ),
                                  },
                                ),
                            initialMonitoringIdentityRuleAuditHistory:
                                <MonitoringIdentityPolicyAuditRecord>[
                                  MonitoringIdentityPolicyAuditRecord(
                                    recordedAtUtc: DateTime.utc(
                                      2026,
                                      3,
                                      15,
                                      7,
                                      14,
                                    ),
                                    source: MonitoringIdentityPolicyAuditSource
                                        .manualEdit,
                                    message:
                                        'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
                                  ),
                                  MonitoringIdentityPolicyAuditRecord(
                                    recordedAtUtc: DateTime.utc(
                                      2026,
                                      3,
                                      15,
                                      7,
                                      10,
                                    ),
                                    source: MonitoringIdentityPolicyAuditSource
                                        .saveRuntime,
                                    message:
                                        'Saved runtime identity rules (1 sites).',
                                  ),
                                ],
                            initialMonitoringIdentityRuleAuditSourceFilter:
                                selectedSource,
                            onMonitoringIdentityRuleAuditSourceFilterChanged:
                                (value) {
                                  setState(() {
                                    selectedSource = value;
                                  });
                                },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 recent'), findsOneWidget);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Saved runtime identity rules (1 sites).'),
        findsNothing,
      );

      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();

      expect(find.text('Recent Rule Changes'), findsOneWidget);
      expect(find.text('1 recent'), findsOneWidget);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Saved runtime identity rules (1 sites).'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'system tab persists identity rule history expansion through parent-owned remounts',
    (tester) async {
      var auditExpanded = true;
      var showAdmin = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAdmin = !showAdmin;
                      });
                    },
                    child: const Text('Toggle admin'),
                  ),
                  Expanded(
                    child: showAdmin
                        ? AdministrationPage(
                            events: const <DispatchEvent>[],
                            supabaseReady: false,
                            initialTab: AdministrationPageTab.system,
                            monitoringIdentityPolicyService:
                                const MonitoringIdentityPolicyService(
                                  policiesByScope: {
                                    'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE':
                                        MonitoringIdentityScopePolicy(
                                          flaggedFaceMatchIds: {'PERSON-44'},
                                        ),
                                  },
                                ),
                            initialMonitoringIdentityRuleAuditHistory:
                                <MonitoringIdentityPolicyAuditRecord>[
                                  MonitoringIdentityPolicyAuditRecord(
                                    recordedAtUtc: DateTime.utc(
                                      2026,
                                      3,
                                      15,
                                      7,
                                      14,
                                    ),
                                    source: MonitoringIdentityPolicyAuditSource
                                        .manualEdit,
                                    message:
                                        'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
                                  ),
                                ],
                            initialMonitoringIdentityRuleAuditExpanded:
                                auditExpanded,
                            onMonitoringIdentityRuleAuditExpandedChanged:
                                (value) {
                                  setState(() {
                                    auditExpanded = value;
                                  });
                                },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collapse'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsOneWidget,
      );

      final auditToggle = find.byKey(const ValueKey('identity-audit-toggle'));
      await tester.ensureVisible(auditToggle);
      await tester.tap(auditToggle);
      await tester.pumpAndSettle();

      expect(auditExpanded, isFalse);
      expect(find.text('Expand'), findsOneWidget);
      expect(find.text('All'), findsNothing);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsNothing,
      );

      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();

      expect(find.text('Recent Rule Changes'), findsOneWidget);
      expect(find.text('Expand'), findsOneWidget);
      expect(find.text('All'), findsNothing);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('system tab can copy, save, and reset identity rules runtime', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );
    MonitoringIdentityPolicyService? savedService;
    var resetCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              initialMonitoringIdentityRulesJson: currentService
                  .toCanonicalJsonString(),
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
              onSaveMonitoringIdentityPolicyService: (value) async {
                savedService = value;
              },
              onResetMonitoringIdentityPolicyService: () async {
                resetCount += 1;
                setState(() {
                  currentService = const MonitoringIdentityPolicyService();
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    final copyJsonButton = find.byKey(
      const ValueKey('identity-rules-copy-json'),
    );
    await tester.ensureVisible(copyJsonButton);
    await tester.tap(copyJsonButton);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('identity-rules-save-runtime')));
    await tester.pump();

    expect(savedService, isNotNull);
    expect(
      savedService!
          .policyFor(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          )
          .flaggedFaceMatchIds,
      contains('PERSON-44'),
    );

    await tester.tap(
      find.byKey(const ValueKey('identity-rules-reset-runtime')),
    );
    await tester.pump();

    expect(resetCount, 1);
    expect(find.text('1 sites'), findsNothing);
  });

  testWidgets('system tab can import identity rules json into runtime', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    final importJsonButton = find.byKey(
      const ValueKey('identity-rules-import-json'),
    );
    await tester.ensureVisible(importJsonButton);
    await tester.tap(importJsonButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('identity-rules-import-text-field')),
      '[{"client_id":"CLIENT-BETA","site_id":"SITE-BETA","flagged_face_match_ids":["PERSON-99"],"allowed_plate_numbers":["ZX12345"]}]',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Import'),
      ),
    );
    await tester.pump();

    expect(find.text('2 sites'), findsNothing);
    expect(find.text('1 sites'), findsOneWidget);
    expect(find.text('SITE-BETA'), findsWidgets);
    expect(find.text('CLIENT-BETA'), findsWidgets);
    expect(
      find.byKey(const ValueKey('identity-rules-entry-selected-SITE-BETA')),
      findsOneWidget,
    );
    expect(find.text('PERSON-99'), findsWidgets);
    expect(find.text('ZX12345'), findsWidgets);
  });

  testWidgets('system tab can import one site policy without replacing others', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]},{"client_id":"CLIENT-BETA","site_id":"SITE-BETA","flagged_face_match_ids":["PERSON-99"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    final importSiteButton = find.byKey(
      const ValueKey('identity-rules-import-site-SITE-MS-VALLEE-RESIDENCE'),
    );
    await tester.ensureVisible(importSiteButton);
    await tester.tap(importSiteButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(
        const ValueKey('identity-rules-site-import-SITE-MS-VALLEE-RESIDENCE'),
      ),
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","flagged_face_match_ids":["PERSON-77"],"allowed_plate_numbers":["CA777777"]}]',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Import'),
      ),
    );
    await tester.pump();

    expect(find.text('2 sites'), findsOneWidget);
    expect(find.text('SITE-BETA'), findsWidgets);
    expect(find.text('PERSON-99'), findsWidgets);
    expect(find.text('PERSON-77'), findsOneWidget);
    expect(find.text('CA777777'), findsOneWidget);
    expect(find.text('PERSON-44'), findsNothing);
    expect(
      currentService
          .policyFor(clientId: 'CLIENT-BETA', siteId: 'SITE-BETA')
          .flaggedFaceMatchIds,
      contains('PERSON-99'),
    );
  });

  testWidgets('system tab can clear one site policy without replacing others', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]},{"client_id":"CLIENT-BETA","site_id":"SITE-BETA","flagged_face_match_ids":["PERSON-99"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    final clearSiteButton = find.byKey(
      const ValueKey('identity-rules-clear-site-SITE-MS-VALLEE-RESIDENCE'),
    );
    await tester.ensureVisible(clearSiteButton);
    await tester.tap(clearSiteButton);
    await tester.pumpAndSettle();

    expect(find.text('Clear Site Identity Rules?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Clear'),
      ),
    );
    await tester.pump();

    expect(find.text('1 sites'), findsOneWidget);
    expect(find.text('SITE-MS-VALLEE-RESIDENCE'), findsNothing);
    expect(find.text('SITE-BETA'), findsWidgets);
    expect(find.text('PERSON-99'), findsWidgets);
    expect(
      currentService
          .policyFor(clientId: 'CLIENT-BETA', siteId: 'SITE-BETA')
          .flaggedFaceMatchIds,
      contains('PERSON-99'),
    );
    expect(
      currentService
          .policyFor(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          )
          .isEmpty,
      isTrue,
    );
  });

  testWidgets('system tab shows suppressed scene review drill-in entries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? openedEventsIncidentRef;
    String? openedLedgerIncidentRef;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          cctvOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:01 UTC',
          fleetScopeHealth: const <VideoFleetScopeHealthView>[
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 1,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Recent',
              isStale: false,
              suppressedCount: 1,
              suppressedHistory: [
                '21:10 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
                '21:08 UTC • Camera 5 • Suppressed because the vehicle path stayed outside the secure boundary.',
              ],
              latestIncidentReference: 'INT-BETA-1',
              latestCameraLabel: 'Camera 2',
              latestSceneDecisionLabel: 'Suppressed',
              latestSceneDecisionSummary:
                  'Suppressed because the activity remained below the client notification threshold.',
            ),
          ],
          sceneReviewByIntelligenceId: <String, MonitoringSceneReviewRecord>{
            'INT-BETA-1': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-BETA-1',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'reviewed',
              decisionLabel: 'Suppressed',
              decisionSummary:
                  'Suppressed because the activity remained below the client notification threshold.',
              summary: 'Vehicle remained below escalation threshold.',
              reviewedAtUtc: DateTime.utc(2026, 3, 13, 21, 14),
            ),
          },
          onOpenEventsForIncident: (incidentRef) {
            openedEventsIncidentRef = incidentRef;
          },
          onOpenLedgerForIncident: (incidentRef) {
            openedLedgerIncidentRef = incidentRef;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisibleText(tester, 'System');
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Filtered 1'));
    await tester.pumpAndSettle();
    final beforeTapOffset = scrollable.position.pixels;
    await tester.tap(find.text('Filtered 1'));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(beforeTapOffset));
    expect(find.text('Focused watch action: Filtered reviews'), findsOneWidget);
    final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(
      textWidgets.indexWhere(
        (widget) => widget.data == 'Suppressed Scene Reviews',
      ),
      lessThan(
        textWidgets.indexWhere((widget) => widget.data == 'CCTV Fleet Health'),
      ),
    );
    expect(find.text('Suppressed Scene Reviews'), findsOneWidget);
    expect(find.text('1 internal'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-suppressed-scene-command')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-suppressed-scene-focus-filtered')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-suppressed-scene-open-events')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-suppressed-scene-open-ledger')),
      findsOneWidget,
    );
    expect(find.text('Beta Watch'), findsWidgets);
    expect(find.text('Action Suppressed'), findsOneWidget);
    expect(find.text('Camera Camera 2'), findsWidgets);
    expect(find.text('Source openai:gpt-4.1-mini'), findsWidgets);
    expect(find.text('Posture reviewed'), findsWidgets);
    expect(
      find.textContaining(
        'Recent filtered reviews: 21:10 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.textContaining(
        'Recent filtered reviews: 21:10 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
      ),
    );
    await tester.pumpAndSettle();
    final beforeSummaryTapOffset = scrollable.position.pixels;
    await tester.tap(
      find.textContaining(
        'Recent filtered reviews: 21:10 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
      ),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, lessThan(beforeSummaryTapOffset));
    expect(
      find.textContaining(
        'Suppressed because the activity remained below the client notification threshold.',
      ),
      findsWidgets,
    );
    expect(
      find.text('Scene review: Vehicle remained below escalation threshold.'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-suppressed-scene-open-events')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-suppressed-scene-open-events')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-suppressed-scene-open-ledger')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-suppressed-scene-open-ledger')),
    );
    await tester.pumpAndSettle();

    expect(openedEventsIncidentRef, 'INT-BETA-1');
    expect(openedLedgerIncidentRef, 'INT-BETA-1');
  });

  testWidgets(
    'system tab fleet actions pass incident reference and ignore watch-only scopes',
    (tester) async {
      String? tappedTacticalClientId;
      String? tappedTacticalSiteId;
      String? tappedTacticalReference;
      String? tappedDispatchClientId;
      String? tappedDispatchSiteId;
      String? tappedDispatchReference;
      String? recoveredClientId;
      String? recoveredSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            cctvOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:01 UTC',
            fleetScopeHealth: const <VideoFleetScopeHealthView>[
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIVE',
                watchLabel: 'ACTIVE',
                recentEvents: 2,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestEventLabel: 'Vehicle motion',
                latestIncidentReference: 'INT-VALLEE-1',
                latestEventTimeLabel: '21:14 UTC',
                latestCameraLabel: 'Camera 1',
                latestRiskScore: 84,
                latestFaceMatchId: 'PERSON-44',
                latestFaceConfidence: 91.2,
                latestPlateNumber: 'CA123456',
                latestPlateConfidence: 96.4,
                latestSceneReviewLabel:
                    'openai:gpt-4.1-mini • identity match concern • 21:14 UTC',
                latestSceneDecisionSummary:
                    'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
              ),
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-B',
                siteId: 'SITE-B',
                siteName: 'Beta Watch',
                endpointLabel: '192.168.8.106',
                statusLabel: 'WATCH READY',
                watchLabel: 'SCHEDULED',
                recentEvents: 0,
                lastSeenLabel: 'idle',
                freshnessLabel: 'Idle',
                isStale: false,
                watchWindowLabel: '18:00-06:00',
                watchWindowStateLabel: 'IN WINDOW',
                watchActivationGapLabel: 'MISSED START',
              ),
            ],
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
              tappedTacticalClientId = clientId;
              tappedTacticalSiteId = siteId;
              tappedTacticalReference = incidentReference;
            },
            onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
              tappedDispatchClientId = clientId;
              tappedDispatchSiteId = siteId;
              tappedDispatchReference = incidentReference;
            },
            onRecoverFleetWatchScope: (clientId, siteId) {
              recoveredClientId = clientId;
              recoveredSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisibleText(tester, 'System');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('MS Vallee Residence').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('MS Vallee Residence').first);
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');

      await tester.ensureVisible(find.text('Dispatch').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dispatch').first);
      await tester.pumpAndSettle();
      expect(tappedDispatchClientId, 'CLIENT-A');
      expect(tappedDispatchSiteId, 'SITE-A');
      expect(tappedDispatchReference, 'INT-VALLEE-1');

      tappedTacticalClientId = null;
      tappedTacticalSiteId = null;
      tappedTacticalReference = null;
      await tester.ensureVisible(find.text('Flagged ID 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flagged ID 1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused identity policy: Flagged identity matches'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.textContaining(
          'Flagged identity: Face PERSON-44 91.2% • Plate CA123456 96.4%',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(
          'Flagged identity: Face PERSON-44 91.2% • Plate CA123456 96.4%',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');
      await tester.ensureVisible(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Resync').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resync').first);
      await tester.pumpAndSettle();
      expect(recoveredClientId, 'CLIENT-B');
      expect(recoveredSiteId, 'SITE-B');

      tappedTacticalClientId = null;
      tappedTacticalSiteId = null;
      tappedTacticalReference = null;
      await tester.ensureVisible(find.text('Beta Watch').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta Watch').first);
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, isNull);
      expect(tappedTacticalSiteId, isNull);
      expect(tappedTacticalReference, isNull);
    },
  );

  testWidgets('system tab renders telegram visitor proposal queue', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          initialTelegramIdentityIntakes: <TelegramIdentityIntakeRecord>[
            TelegramIdentityIntakeRecord(
              intakeId: 'intake-1',
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              rawText:
                  'John Smith is visiting in a white Hilux CA123456 until 18:00',
              parsedDisplayName: 'John Smith',
              parsedFaceMatchId: 'PERSON-44',
              parsedPlateNumber: 'CA123456',
              category: SiteIdentityCategory.visitor,
              aiConfidence: 0.92,
              approvalState: 'proposed',
              createdAtUtc: DateTime.utc(2026, 3, 15, 10, 45),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Telegram Visitor Proposals'), findsOneWidget);
    expect(find.text('1 pending'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-telegram-intake-command')),
      findsOneWidget,
    );
    expect(find.text('John Smith'), findsWidgets);
    expect(
      find.text('John Smith is visiting in a white Hilux CA123456 until 18:00'),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('admin-telegram-intake-lead-once-intake-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-telegram-intake-lead-always-intake-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-telegram-intake-lead-reject-intake-1')),
      findsOneWidget,
    );
    expect(find.text('Allow Once'), findsOneWidget);
    expect(find.text('Always Allow'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('system tab telegram lead command pins desktop receipt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          initialTelegramIdentityIntakes: <TelegramIdentityIntakeRecord>[
            TelegramIdentityIntakeRecord(
              intakeId: 'intake-1',
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              rawText:
                  'John Smith is visiting in a white Hilux CA123456 until 18:00',
              parsedDisplayName: 'John Smith',
              parsedFaceMatchId: 'PERSON-44',
              parsedPlateNumber: 'CA123456',
              category: SiteIdentityCategory.visitor,
              aiConfidence: 0.92,
              approvalState: 'proposed',
              createdAtUtc: DateTime.utc(2026, 3, 15, 10, 45),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-telegram-intake-command')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-telegram-intake-lead-once-intake-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(
      find.text('Supabase required to action Telegram visitor proposals.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('system tab renders polished telegram ai draft review cards', (
    tester,
  ) async {
    final nowUtc = DateTime.now().toUtc();
    String? openedClientId;
    String? openedSiteId;
    String? profiledClientId;
    String? profiledSiteId;
    String? profiledSignal;
    String? clearedClientId;
    String? clearedSiteId;
    String? pinnedClientId;
    String? pinnedSiteId;
    String? demotedClientId;
    String? demotedSiteId;
    String? promotedLearnedText;
    String? demotedLearnedText;
    String? taggedLearnedText;
    String? savedLearnedTag;
    var liveOpsQueueHintResetCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          telegramAiPendingDrafts: <TelegramAiPendingDraftView>[
            TelegramAiPendingDraftView(
              updateId: 42,
              audience: 'client',
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              chatId: '123456',
              messageThreadId: 88,
              sourceText:
                  'Can you please tell me what is happening at the house?',
              draftText:
                  'We are checking the latest position now and I will send you the next confirmed update as soon as it is in.',
              providerLabel: 'openai:gpt-4.1-mini',
              clientProfileOverrideSignal: 'reassurance-forward',
              learnedRewriteCount: 2,
              learnedRewriteExample:
                  'Control is checking the latest position now and will share the next confirmed step shortly.',
              learnedRewriteTag: 'Warm reassurance',
              learnedRewriteApprovalCount: 4,
              learnedRewriteLastUsedAtUtc: nowUtc.subtract(
                const Duration(hours: 2),
              ),
              learnedRewritePreviews: [
                TelegramAiLearnedStylePreviewView(
                  text:
                      'Control is checking the latest position now and will share the next confirmed step shortly.',
                  operatorTag: 'Warm reassurance',
                  approvalCount: 4,
                  lastUsedAtUtc: nowUtc.subtract(const Duration(hours: 2)),
                ),
                TelegramAiLearnedStylePreviewView(
                  text:
                      'You are not alone. Control is checking now and will keep this lane updated.',
                  operatorTag: 'Resident comfort',
                  approvalCount: 3,
                  lastUsedAtUtc: nowUtc.subtract(const Duration(hours: 5)),
                ),
                TelegramAiLearnedStylePreviewView(
                  text:
                      'Control is checking cameras now and will share the next confirmed camera check shortly.',
                  approvalCount: 2,
                ),
              ],
              usesLearnedApprovalStyle: true,
              createdAtUtc: DateTime.utc(2026, 3, 18, 12, 30),
            ),
          ],
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
          onSetTelegramAiClientProfileOverride:
              ({required clientId, required siteId, profileSignal}) async {
                profiledClientId = clientId;
                profiledSiteId = siteId;
                profiledSignal = profileSignal;
              },
          onClearTelegramAiLearnedStyleForScope:
              ({required clientId, required siteId}) async {
                clearedClientId = clientId;
                clearedSiteId = siteId;
              },
          onPinTelegramAiLearnedStyleForScope:
              ({required clientId, required siteId}) async {
                pinnedClientId = clientId;
                pinnedSiteId = siteId;
              },
          onDemoteTelegramAiLearnedStyleForScope:
              ({required clientId, required siteId}) async {
                demotedClientId = clientId;
                demotedSiteId = siteId;
              },
          onPinTelegramAiLearnedStyleEntryForScope:
              ({
                required clientId,
                required siteId,
                required learnedText,
              }) async {
                promotedLearnedText = learnedText;
              },
          onDemoteTelegramAiLearnedStyleEntryForScope:
              ({
                required clientId,
                required siteId,
                required learnedText,
              }) async {
                demotedLearnedText = learnedText;
              },
          onTagTelegramAiLearnedStyleEntryForScope:
              ({
                required clientId,
                required siteId,
                required learnedText,
                operatorTag,
              }) async {
                taggedLearnedText = learnedText;
                savedLearnedTag = operatorTag;
              },
          onResetLiveOperationsQueueHint: () async {
            liveOpsQueueHintResetCount += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Telegram AI Assistant'), findsOneWidget);
    expect(
      find.text(
        'Client voice goal: calm, premium, and operator-backed. Every approved draft should feel like a capable control room, not a chatbot.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Vallee Residence'), findsOneWidget);
    expect(find.textContaining('OpenAI'), findsOneWidget);
    expect(find.text('Awaiting human sign-off'), findsOneWidget);
    expect(find.text('Client Lane'), findsOneWidget);
    expect(find.text('CLIENT ASKED'), findsOneWidget);
    expect(find.text('ONYX WILL SAY'), findsOneWidget);
    expect(find.text('Approve + Send'), findsOneWidget);
    expect(find.text('Open This Lane'), findsOneWidget);
    expect(find.text('Lane voice: Reassuring'), findsOneWidget);
    expect(find.text('Voice-adjusted'), findsOneWidget);
    expect(find.text('Learned from approvals (2)'), findsOneWidget);
    expect(find.text('Uses learned approval style'), findsOneWidget);
    expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
    expect(
      find.text(
        'This draft is already leaning on learned approval wording from this lane.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Lead with calm reassurance first, then the next confirmed step.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ),
      findsOneWidget,
    );
    expect(find.text('Warm reassurance'), findsOneWidget);
    expect(find.textContaining('Approved 4x'), findsOneWidget);
    expect(find.textContaining('Last used 2h ago'), findsOneWidget);
    expect(find.text('NEXT LEARNED OPTIONS'), findsOneWidget);
    expect(
      find.textContaining(
        '#2 You are not alone. Control is checking now and will keep this lane updated.',
      ),
      findsOneWidget,
    );
    expect(find.text('Resident comfort'), findsOneWidget);
    expect(
      find.textContaining(
        '#3 Control is checking cameras now and will share the next confirmed camera check shortly.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Promote #2'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Demote #2'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Tag Top Style'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Tag #2'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Pin Top Style'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Demote Top Style'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Clear Learned Style'),
      findsOneWidget,
    );
    expect(find.byKey(liveOpsTipResetDraftButtonKey), findsOneWidget);
    expect(find.byKey(liveOpsTipResetAuditButtonKey), findsNothing);
    expect(find.text(liveOpsTipResetNote), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reassuring'), findsOneWidget);
    expect(profileButtonLabels(tester).take(4).toList(), <String>[
      'Auto',
      'Reassuring',
      'Concise',
      'Validation-heavy',
    ]);

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Reassuring'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reassuring'));
    await tester.pumpAndSettle();

    expect(profiledClientId, 'CLIENT-MS-VALLEE');
    expect(profiledSiteId, 'SITE-MS-VALLEE-RESIDENCE');
    expect(profiledSignal, 'reassurance-forward');

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Clear Learned Style'),
    );
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Clear Learned Style'),
    );
    await tester.pumpAndSettle();

    expect(clearedClientId, 'CLIENT-MS-VALLEE');
    expect(clearedSiteId, 'SITE-MS-VALLEE-RESIDENCE');

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Pin Top Style'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Pin Top Style'));
    await tester.pumpAndSettle();

    expect(pinnedClientId, 'CLIENT-MS-VALLEE');
    expect(pinnedSiteId, 'SITE-MS-VALLEE-RESIDENCE');

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Demote Top Style'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Demote Top Style'));
    await tester.pumpAndSettle();

    expect(demotedClientId, 'CLIENT-MS-VALLEE');
    expect(demotedSiteId, 'SITE-MS-VALLEE-RESIDENCE');

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Promote #2'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Promote #2'));
    await tester.pumpAndSettle();

    expect(
      promotedLearnedText,
      'You are not alone. Control is checking now and will keep this lane updated.',
    );

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Demote #2'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Demote #2'));
    await tester.pumpAndSettle();

    expect(
      demotedLearnedText,
      'You are not alone. Control is checking now and will keep this lane updated.',
    );

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Tag Top Style'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tag Top Style'));
    await tester.pumpAndSettle();
    expect(find.text('Suggested tags'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Operations formal'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Operations formal'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Tag'));
    await tester.pumpAndSettle();

    expect(
      taggedLearnedText,
      'Control is checking the latest position now and will share the next confirmed step shortly.',
    );
    expect(savedLearnedTag, 'Operations formal');

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Tag #2'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tag #2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Arrival reassurance',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Tag'));
    await tester.pumpAndSettle();

    expect(
      taggedLearnedText,
      'You are not alone. Control is checking now and will keep this lane updated.',
    );
    expect(savedLearnedTag, 'Arrival reassurance');

    await tester.ensureVisible(find.byKey(liveOpsTipResetDraftButtonKey));
    await tester.tap(find.byKey(liveOpsTipResetDraftButtonKey));
    await tester.pumpAndSettle();

    expect(liveOpsQueueHintResetCount, 1);

    await tester.ensureVisible(find.text('Open This Lane'));
    await tester.tap(find.text('Open This Lane'));
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-MS-VALLEE');
    expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
  });

  testWidgets('system tab renders client comms audit cards', (tester) async {
    final nowUtc = DateTime.now().toUtc();
    String? openedClientId;
    String? openedSiteId;
    String? profiledClientId;
    String? profiledSiteId;
    String? profiledSignal;
    String? pinnedClientId;
    String? pinnedSiteId;
    String? demotedClientId;
    String? demotedSiteId;
    String? promotedLearnedText;
    String? demotedLearnedText;
    String? taggedLearnedText;
    String? savedLearnedTag;
    var liveOpsQueueHintResetCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          clientCommsAuditViews: <ClientCommsAuditView>[
            ClientCommsAuditView(
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              matchesSelectedScope: true,
              pendingApprovalCount: 1,
              pendingLearnedStyleDraftCount: 1,
              learnedApprovalStyleCount: 2,
              learnedApprovalStyleExample:
                  'Control is checking the latest position now and will share the next confirmed step shortly.',
              learnedApprovalStyleTag: 'Warm reassurance',
              learnedApprovalStyleApprovalCount: 3,
              learnedApprovalStyleLastUsedAtUtc: nowUtc.subtract(
                const Duration(hours: 1),
              ),
              learnedApprovalStylePreviews: [
                TelegramAiLearnedStylePreviewView(
                  text:
                      'Control is checking the latest position now and will share the next confirmed step shortly.',
                  operatorTag: 'Warm reassurance',
                  approvalCount: 3,
                  lastUsedAtUtc: nowUtc.subtract(const Duration(hours: 1)),
                ),
                TelegramAiLearnedStylePreviewView(
                  text:
                      'You are not alone. Control is checking now and will keep this lane updated.',
                  operatorTag: 'Resident comfort',
                  approvalCount: 2,
                  lastUsedAtUtc: nowUtc.subtract(const Duration(hours: 4)),
                ),
                TelegramAiLearnedStylePreviewView(
                  text:
                      'Control is checking cameras now and will share the next confirmed camera check shortly.',
                  approvalCount: 1,
                ),
              ],
              latestLaneReplyBody:
                  'Waterfall control lane update: desk has logged the resident follow-up.',
              latestLaneReplyAtUtc: DateTime.utc(2026, 3, 18, 12, 37),
              queuedPushCount: 1,
              pushSyncStatusLabel: 'failed',
              pushSyncFailureReason:
                  'Waterfall push sync needs operator review before retry.',
              clientProfileOverrideSignal: 'reassurance-forward',
              telegramHealthLabel: 'blocked',
              smsFallbackLabel: 'SMS fallback ready',
              voiceReadinessLabel: 'VoIP ready',
              deliveryReadinessDetail:
                  'Telegram stays primary, but fallback channels are ready for this lane.',
              latestSmsFallbackStatus:
                  'sms:bulksms sent 2/2 after telegram blocked.',
              latestSmsFallbackAtUtc: DateTime.utc(2026, 3, 18, 12, 35),
              latestVoipStageStatus:
                  'voip:asterisk staged call for Vallee command desk.',
              latestVoipStageAtUtc: DateTime.utc(2026, 3, 18, 12, 36),
              recentDeliveryHistoryLines: const <String>[
                '12:36 UTC • voip staged • queue:1 • Asterisk staged a call for Vallee command desk.',
                '12:35 UTC • sms fallback sent • queue:1 • BulkSMS reached 2/2 contacts after Telegram was blocked.',
              ],
            ),
          ],
          onOpenClientViewForScope: (clientId, siteId) {
            openedClientId = clientId;
            openedSiteId = siteId;
          },
          onSetTelegramAiClientProfileOverride:
              ({required clientId, required siteId, profileSignal}) async {
                profiledClientId = clientId;
                profiledSiteId = siteId;
                profiledSignal = profileSignal;
              },
          onPinTelegramAiLearnedStyleForScope:
              ({required clientId, required siteId}) async {
                pinnedClientId = clientId;
                pinnedSiteId = siteId;
              },
          onDemoteTelegramAiLearnedStyleForScope:
              ({required clientId, required siteId}) async {
                demotedClientId = clientId;
                demotedSiteId = siteId;
              },
          onPinTelegramAiLearnedStyleEntryForScope:
              ({
                required clientId,
                required siteId,
                required learnedText,
              }) async {
                promotedLearnedText = learnedText;
              },
          onDemoteTelegramAiLearnedStyleEntryForScope:
              ({
                required clientId,
                required siteId,
                required learnedText,
              }) async {
                demotedLearnedText = learnedText;
              },
          onTagTelegramAiLearnedStyleEntryForScope:
              ({
                required clientId,
                required siteId,
                required learnedText,
                operatorTag,
              }) async {
                taggedLearnedText = learnedText;
                savedLearnedTag = operatorTag;
              },
          onResetLiveOperationsQueueHint: () async {
            liveOpsQueueHintResetCount += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Client Comms Audit'), findsOneWidget);
    expect(
      find.text(
        'Latest push sync pressure, SMS fallback, and VoIP handoff results across active client lanes, so control can verify what ONYX actually tried.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Vallee Residence'), findsOneWidget);
    expect(find.textContaining('Voice Reassuring'), findsOneWidget);
    expect(
      find.textContaining(
        'Telegram blocked • Push needs review • SMS fallback ready • VoIP ready',
      ),
      findsOneWidget,
    );
    expect(find.text('Selected lane'), findsOneWidget);
    expect(find.text('Lane voice: Reassuring'), findsOneWidget);
    expect(find.text('Voice-adjusted'), findsOneWidget);
    expect(
      find.text(
        'Lead with calm reassurance first, then the next confirmed step.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 pending draft'), findsOneWidget);
    expect(find.text('Learned style (2)'), findsOneWidget);
    expect(find.text('ONYX using learned style'), findsOneWidget);
    expect(find.text('Push FAILED'), findsOneWidget);
    expect(find.text('1 push item queued'), findsOneWidget);
    expect(find.text('LATEST SMS FALLBACK'), findsOneWidget);
    expect(find.text('LATEST VOIP STAGE'), findsOneWidget);
    expect(find.text('LATEST PUSH DETAIL'), findsOneWidget);
    expect(find.text('RECENT DELIVERY HISTORY'), findsOneWidget);
    expect(find.text('LATEST LANE REPLY'), findsOneWidget);
    expect(find.text('LEARNED APPROVAL STYLE'), findsOneWidget);
    expect(find.text('Warm reassurance'), findsOneWidget);
    expect(find.textContaining('Approved 3x'), findsOneWidget);
    expect(find.textContaining('Last used 1h ago'), findsOneWidget);
    expect(find.text('NEXT LEARNED OPTIONS'), findsOneWidget);
    expect(
      find.textContaining(
        '#2 You are not alone. Control is checking now and will keep this lane updated.',
      ),
      findsOneWidget,
    );
    expect(find.text('Resident comfort'), findsOneWidget);
    expect(
      find.textContaining(
        '#3 Control is checking cameras now and will share the next confirmed camera check shortly.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Promote #2'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Demote #2'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Tag Top Style'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Tag #2'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Pin Top Style'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Demote Top Style'),
      findsOneWidget,
    );
    expect(find.byKey(liveOpsTipResetAuditButtonKey), findsOneWidget);
    expect(find.byKey(liveOpsTipResetDraftButtonKey), findsNothing);
    expect(find.text(liveOpsTipResetNote), findsOneWidget);
    expect(
      find.textContaining(
        'BulkSMS reached 2/2 contacts after Telegram was blocked.',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining('Asterisk staged a call for Vallee command desk.'),
      findsWidgets,
    );
    expect(
      find.textContaining('12:36 UTC • voip staged • queue:1'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Waterfall push sync needs operator review before retry.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Waterfall control lane update: desk has logged the resident follow-up.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Concise'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Concise'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Concise'));
    await tester.pumpAndSettle();

    expect(profiledClientId, 'CLIENT-MS-VALLEE');
    expect(profiledSiteId, 'SITE-MS-VALLEE-RESIDENCE');
    expect(profiledSignal, 'concise-updates');

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Pin Top Style'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Pin Top Style'));
    await tester.pumpAndSettle();

    expect(pinnedClientId, 'CLIENT-MS-VALLEE');
    expect(pinnedSiteId, 'SITE-MS-VALLEE-RESIDENCE');

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Demote Top Style'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Demote Top Style'));
    await tester.pumpAndSettle();

    expect(demotedClientId, 'CLIENT-MS-VALLEE');
    expect(demotedSiteId, 'SITE-MS-VALLEE-RESIDENCE');

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Promote #2'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Promote #2'));
    await tester.pumpAndSettle();

    expect(
      promotedLearnedText,
      'You are not alone. Control is checking now and will keep this lane updated.',
    );

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Demote #2'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Demote #2'));
    await tester.pumpAndSettle();

    expect(
      demotedLearnedText,
      'You are not alone. Control is checking now and will keep this lane updated.',
    );

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Tag Top Style'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tag Top Style'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Resident update',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Tag'));
    await tester.pumpAndSettle();

    expect(
      taggedLearnedText,
      'Control is checking the latest position now and will share the next confirmed step shortly.',
    );
    expect(savedLearnedTag, 'Resident update');

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Tag #2'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tag #2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Follow-up reassurance',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Tag'));
    await tester.pumpAndSettle();

    expect(
      taggedLearnedText,
      'You are not alone. Control is checking now and will keep this lane updated.',
    );
    expect(savedLearnedTag, 'Follow-up reassurance');

    await tester.ensureVisible(find.byKey(liveOpsTipResetAuditButtonKey));
    await tester.tap(find.byKey(liveOpsTipResetAuditButtonKey));
    await tester.pumpAndSettle();

    expect(liveOpsQueueHintResetCount, 1);

    expect(find.text('Open This Lane'), findsOneWidget);

    await tester.ensureVisible(find.text('Open This Lane'));
    await tester.tap(find.text('Open This Lane'));
    await tester.pumpAndSettle();

    expect(openedClientId, 'CLIENT-MS-VALLEE');
    expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
  });

  testWidgets('system tab pins failure receipt when live ops tip reset fails', (
    tester,
  ) async {
    await pumpAdminWithLiveOpsTipResetDraft(
      tester,
      updateId: 91,
      createdAtUtc: DateTime.utc(2026, 3, 18, 13, 25),
      onReset: () async {
        throw Exception('reset failed');
      },
    );

    expectLiveOpsTipResetButtonSurface(tester, audit: false);
    await tapLiveOpsTipResetButton(tester, audit: false);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
        matching: find.text(liveOpsTipResetFailureSnack),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'system tab pins success receipt when live ops tip reset succeeds',
    (tester) async {
      var resetCount = 0;

      await pumpAdminWithLiveOpsTipResetDraft(
        tester,
        updateId: 92,
        createdAtUtc: DateTime.utc(2026, 3, 18, 13, 26),
        onReset: () async {
          resetCount += 1;
        },
      );

      expectLiveOpsTipResetButtonSurface(tester, audit: false);
      await tapLiveOpsTipResetButton(tester, audit: false);
      await tester.pumpAndSettle();

      expect(resetCount, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(liveOpsTipResetSuccessSnack),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'system tab disables live ops tip reset button while reset is in flight',
    (tester) async {
      final resetCompleter = Completer<void>();
      var resetCount = 0;

      await pumpAdminWithLiveOpsTipResetDraft(
        tester,
        updateId: 93,
        createdAtUtc: DateTime.utc(2026, 3, 18, 13, 27),
        onReset: () async {
          resetCount += 1;
          await resetCompleter.future;
        },
      );

      expectLiveOpsTipResetButtonSurface(tester, audit: false);
      final resetButtonFinder = liveOpsTipResetButtonFinder(audit: false);
      await tester.ensureVisible(resetButtonFinder);
      await tester.tap(resetButtonFinder);
      await tester.pump();

      expect(resetCount, 1);
      expect(
        tester.widget<OutlinedButton>(resetButtonFinder).onPressed,
        isNull,
      );

      resetCompleter.complete();
      await tester.pumpAndSettle();

      expect(
        tester.widget<OutlinedButton>(resetButtonFinder).onPressed,
        isNotNull,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(liveOpsTipResetSuccessSnack),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'system tab pins success receipt when audit live ops tip reset succeeds',
    (tester) async {
      final nowUtc = DateTime.now().toUtc();
      var resetCount = 0;

      await pumpAdminWithLiveOpsTipResetAudit(
        tester,
        nowUtc: nowUtc,
        onReset: () async {
          resetCount += 1;
        },
      );

      expectLiveOpsTipResetButtonSurface(tester, audit: true);
      await tapLiveOpsTipResetButton(tester, audit: true);
      await tester.pumpAndSettle();

      expect(resetCount, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(liveOpsTipResetSuccessSnack),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'system tab pins failure receipt when audit live ops tip reset fails',
    (tester) async {
      final nowUtc = DateTime.now().toUtc();

      await pumpAdminWithLiveOpsTipResetAudit(
        tester,
        nowUtc: nowUtc,
        onReset: () async {
          throw Exception('reset failed');
        },
      );

      expectLiveOpsTipResetButtonSurface(tester, audit: true);
      await tapLiveOpsTipResetButton(tester, audit: true);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(liveOpsTipResetFailureSnack),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'system tab disables audit live ops tip reset button while reset is in flight',
    (tester) async {
      final nowUtc = DateTime.now().toUtc();
      final resetCompleter = Completer<void>();
      var resetCount = 0;

      await pumpAdminWithLiveOpsTipResetAudit(
        tester,
        nowUtc: nowUtc,
        onReset: () async {
          resetCount += 1;
          await resetCompleter.future;
        },
      );

      expectLiveOpsTipResetButtonSurface(tester, audit: true);
      final resetButtonFinder = liveOpsTipResetButtonFinder(audit: true);
      await tester.ensureVisible(resetButtonFinder);
      await tester.tap(resetButtonFinder);
      await tester.pump();

      expect(resetCount, 1);
      expect(
        tester.widget<OutlinedButton>(resetButtonFinder).onPressed,
        isNull,
      );

      resetCompleter.complete();
      await tester.pumpAndSettle();

      expect(
        tester.widget<OutlinedButton>(resetButtonFinder).onPressed,
        isNotNull,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-workspace-command-receipt')),
          matching: find.text(liveOpsTipResetSuccessSnack),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'system tab suggests operations formal first for enterprise learned style tags',
    (tester) async {
      String? savedLearnedTag;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            telegramAiPendingDrafts: <TelegramAiPendingDraftView>[
              TelegramAiPendingDraftView(
                updateId: 77,
                audience: 'client',
                clientId: 'CLIENT-SANDTON',
                siteId: 'SITE-SANDTON-TOWER',
                chatId: '998877',
                sourceText: 'Any update?',
                draftText:
                    'We are checking Sandton Tower now. I will update you here with the next confirmed step.',
                providerLabel: 'openai:gpt-4.1-mini',
                learnedRewriteCount: 1,
                learnedRewriteExample:
                    'We are checking Sandton Tower now. I will update you here with the next confirmed step.',
                learnedRewritePreviews: [
                  TelegramAiLearnedStylePreviewView(
                    text:
                        'We are checking Sandton Tower now. I will update you here with the next confirmed step.',
                    approvalCount: 2,
                  ),
                ],
                createdAtUtc: DateTime.utc(2026, 3, 18, 13, 15),
              ),
            ],
            onTagTelegramAiLearnedStyleEntryForScope:
                ({
                  required clientId,
                  required siteId,
                  required learnedText,
                  operatorTag,
                }) async {
                  savedLearnedTag = operatorTag;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Tag Top Style'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tag Top Style'));
      await tester.pumpAndSettle();

      expect(find.text('Suggested tags'), findsOneWidget);
      final suggestedButtons = tester
          .widgetList<OutlinedButton>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(OutlinedButton),
            ),
          )
          .toList(growable: false);
      final firstSuggestedLabel = ((suggestedButtons.first.child as Text).data);
      expect(firstSuggestedLabel, 'Operations formal');

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(OutlinedButton, 'Operations formal'),
        ),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Tag'));
      await tester.pumpAndSettle();

      expect(savedLearnedTag, 'Operations formal');
    },
  );

  testWidgets(
    'system tab floats warm reassurance first when enterprise learned style already reads protective',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            telegramAiPendingDrafts: <TelegramAiPendingDraftView>[
              TelegramAiPendingDraftView(
                updateId: 78,
                audience: 'client',
                clientId: 'CLIENT-SANDTON',
                siteId: 'SITE-SANDTON-TOWER',
                chatId: '554433',
                sourceText: 'I am worried, what is happening?',
                draftText:
                    'We are checking Sandton Tower now and taking this seriously. I will update you here with the next confirmed step.',
                providerLabel: 'openai:gpt-4.1-mini',
                learnedRewriteCount: 1,
                learnedRewriteExample:
                    'You are not alone. We are treating this as live at Sandton Tower and checking it now.',
                learnedRewriteTag: 'Warm reassurance',
                learnedRewritePreviews: [
                  TelegramAiLearnedStylePreviewView(
                    text:
                        'You are not alone. We are treating this as live at Sandton Tower and checking it now.',
                    operatorTag: 'Warm reassurance',
                    approvalCount: 3,
                  ),
                ],
                createdAtUtc: DateTime.utc(2026, 3, 18, 13, 25),
              ),
            ],
            onTagTelegramAiLearnedStyleEntryForScope:
                ({
                  required clientId,
                  required siteId,
                  required learnedText,
                  operatorTag,
                }) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Tag Top Style'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tag Top Style'));
      await tester.pumpAndSettle();

      final suggestedButtons = tester
          .widgetList<OutlinedButton>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(OutlinedButton),
            ),
          )
          .toList(growable: false);
      final firstSuggestedLabel = ((suggestedButtons.first.child as Text).data);
      expect(firstSuggestedLabel, 'Warm reassurance');
    },
  );

  testWidgets(
    'system tab floats validation-heavy first when learned style already reads camera-focused',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            telegramAiPendingDrafts: <TelegramAiPendingDraftView>[
              TelegramAiPendingDraftView(
                updateId: 79,
                audience: 'client',
                clientId: 'CLIENT-SANDTON',
                siteId: 'SITE-SANDTON-TOWER',
                chatId: '667788',
                sourceText: 'What do you see on camera?',
                draftText:
                    'We are checking cameras at Sandton Tower now. I will update you here with the latest confirmed camera check.',
                providerLabel: 'openai:gpt-4.1-mini',
                learnedRewriteCount: 1,
                learnedRewriteExample:
                    'We are checking cameras and daylight at Sandton Tower now. I will update you here with the next confirmed camera check.',
                learnedRewriteTag: 'Camera validation',
                learnedRewritePreviews: [
                  TelegramAiLearnedStylePreviewView(
                    text:
                        'We are checking cameras and daylight at Sandton Tower now. I will update you here with the next confirmed camera check.',
                    operatorTag: 'Camera validation',
                    approvalCount: 2,
                  ),
                ],
                createdAtUtc: DateTime.utc(2026, 3, 18, 13, 35),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(profileButtonLabels(tester).take(4).toList(), <String>[
        'Auto',
        'Validation-heavy',
        'Concise',
        'Reassuring',
      ]);
      expect(
        find.text(
          'Keep the camera wording concrete and make sure the exact check is clear before sending.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('system tab shows client comms audit empty state copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          clientCommsAuditViews: const <ClientCommsAuditView>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Client Comms Audit'), findsOneWidget);
    expect(
      find.text(
        'Client comms delivery and handoff history will appear here as soon as ONYX stages, queues, or sends one.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('system tab humanizes telegram bridge detail in audit cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          clientCommsAuditViews: <ClientCommsAuditView>[
            ClientCommsAuditView(
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'WTF-MAIN',
              matchesSelectedScope: false,
              telegramHealthLabel: 'blocked',
              pushSyncStatusLabel: 'failed',
              pushSyncFailureReason:
                  'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
              smsFallbackLabel: 'SMS fallback ready',
              voiceReadinessLabel: 'VoIP staged',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Client Comms Audit'), findsOneWidget);
    expect(find.text('Telegram BLOCKED'), findsWidgets);
    expect(find.text('LATEST PUSH DETAIL'), findsOneWidget);
    expect(
      find.textContaining(
        'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
      ),
      findsWidgets,
    );
  });

  testWidgets('system tab can refine telegram ai draft before approval', (
    tester,
  ) async {
    String draftText =
        'We are checking the latest position now and I will send you the next confirmed update as soon as it is in.';
    String? approvedDraftText;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              initialTab: AdministrationPageTab.system,
              telegramAiPendingDrafts: <TelegramAiPendingDraftView>[
                TelegramAiPendingDraftView(
                  updateId: 42,
                  audience: 'client',
                  clientId: 'CLIENT-MS-VALLEE',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                  chatId: '123456',
                  messageThreadId: 88,
                  sourceText:
                      'Can you please tell me what is happening at the house?',
                  draftText: draftText,
                  providerLabel: 'openai:gpt-4.1-mini',
                  usesLearnedApprovalStyle: true,
                  createdAtUtc: DateTime.utc(2026, 3, 18, 12, 30),
                ),
              ],
              onUpdateTelegramAiDraftText: (updateId, nextText) async {
                setState(() {
                  draftText = nextText;
                });
              },
              onApproveTelegramAiDraft:
                  (updateId, {String? approvedText}) async {
                    approvedDraftText = approvedText;
                    return 'approved=$updateId';
                  },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editDraftButton = find.widgetWithText(OutlinedButton, 'Edit Draft');
    await tester.ensureVisible(editDraftButton);
    await tester.tap(editDraftButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Control is checking the latest Vallee position now and will share the next confirmed step shortly.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Draft'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Control is checking the latest Vallee position now and will share the next confirmed step shortly.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Approve + Send'));
    await tester.pumpAndSettle();

    expect(
      approvedDraftText,
      'Control is checking the latest Vallee position now and will share the next confirmed step shortly.',
    );
  });

  testWidgets(
    'system tab temporary identity summary opens incident-backed scope detail',
    (tester) async {
      String? tappedTacticalClientId;
      String? tappedTacticalSiteId;
      String? tappedTacticalReference;
      String? extendedSite;
      String? expiredSite;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            fleetScopeHealth: const <VideoFleetScopeHealthView>[
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIVE',
                watchLabel: 'ACTIVE',
                recentEvents: 1,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestIncidentReference: 'INT-VALLEE-1',
                latestEventTimeLabel: '21:14 UTC',
                latestCameraLabel: 'Camera 1',
                latestFaceMatchId: 'VISITOR-01',
                latestFaceConfidence: 93.1,
                latestPlateNumber: 'CA777777',
                latestPlateConfidence: 97.4,
                latestSceneReviewLabel:
                    'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
                latestSceneDecisionSummary:
                    'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
              ),
            ],
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
              tappedTacticalClientId = clientId;
              tappedTacticalSiteId = siteId;
              tappedTacticalReference = incidentReference;
            },
            onExtendTemporaryIdentityApproval: (scope) async {
              extendedSite = scope.siteName;
              return 'Extended ${scope.siteName}.';
            },
            onExpireTemporaryIdentityApproval: (scope) async {
              expiredSite = scope.siteName;
              return 'Expired ${scope.siteName}.';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Temporary ID 1'), findsOneWidget);
      expect(
        find.textContaining(
          'Identity policy: Temporary approval until 2026-03-15 18:00 UTC',
        ),
        findsOneWidget,
      );
      expect(find.text('Identity Temporary'), findsOneWidget);
      await tester.ensureVisible(find.text('Temporary ID 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temporary ID 1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Focused identity policy: Temporary identity approvals'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Extend 2h'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused identity policy: Temporary identity approvals'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Showing fleet scopes where ONYX matched a one-time approved face or plate.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Soonest expiry: MS Vallee Residence'),
        findsOneWidget,
      );
      expect(find.text('Extend 2h'), findsOneWidget);
      expect(find.text('Expire now'), findsOneWidget);
      await tester.tap(find.text('Extend 2h'));
      await tester.pumpAndSettle();
      expect(extendedSite, 'MS Vallee Residence');
      await tester.tap(find.text('Expire now'));
      await tester.pumpAndSettle();
      expect(find.text('Expire Temporary Approval?'), findsOneWidget);
      expect(
        find.textContaining(
          'This immediately removes the temporary identity approval for MS Vallee Residence.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Expire now'));
      await tester.pumpAndSettle();
      expect(expiredSite, 'MS Vallee Residence');
      await tester.ensureVisible(
        find.textContaining(
          'Temporary identity until 2026-03-15 18:00 UTC: Face VISITOR-01 93.1% • Plate CA777777 97.4%',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(
          'Temporary identity until 2026-03-15 18:00 UTC: Face VISITOR-01 93.1% • Plate CA777777 97.4%',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');
    },
  );

  testWidgets(
    'system tab allowlisted identity summary opens incident-backed scope detail',
    (tester) async {
      String? tappedTacticalClientId;
      String? tappedTacticalSiteId;
      String? tappedTacticalReference;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            fleetScopeHealth: const <VideoFleetScopeHealthView>[
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIVE',
                watchLabel: 'ACTIVE',
                recentEvents: 1,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestIncidentReference: 'INT-VALLEE-1',
                latestEventTimeLabel: '21:14 UTC',
                latestCameraLabel: 'Camera 1',
                latestFaceMatchId: 'RESIDENT-01',
                latestFaceConfidence: 94.1,
                latestPlateNumber: 'CA111111',
                latestPlateConfidence: 98.0,
                latestSceneReviewLabel:
                    'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
                latestSceneDecisionSummary:
                    'Suppressed because RESIDENT-01 and plate CA111111 are allowlisted for this site.',
              ),
            ],
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
              tappedTacticalClientId = clientId;
              tappedTacticalSiteId = siteId;
              tappedTacticalReference = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allowed ID 1'), findsOneWidget);
      expect(find.text('Identity Allowlisted'), findsOneWidget);
      await tester.ensureVisible(find.text('Allowed ID 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allowed ID 1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused identity policy: Allowlisted identity matches'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.textContaining(
          'Allowlisted identity: Face RESIDENT-01 94.1% • Plate CA111111 98.0%',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(
          'Allowlisted identity: Face RESIDENT-01 94.1% • Plate CA111111 98.0%',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');
    },
  );
}
