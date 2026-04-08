import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

DateTime _clientAppOccurredAtUtc(int day, int hour, int minute) =>
    DateTime.utc(2026, 3, day, hour, minute);

void main() {
  Finder richDetailLine(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
    );
  }

  test('client app locale maps include all used general keys', () {
    final source = File('lib/ui/client_app_page.dart').readAsStringSync();
    final templateKeyPattern = RegExp(r"_localizedTemplate\(\s*key: '([^']+)'");
    final generalTextKeyPattern = RegExp(
      r"ClientAppLocaleText\.generalText\(\s*\n?\s*locale: [^\n]+,\s*\n?\s*key: '([^']+)'",
    );
    final usedGeneralKeys = <String>{
      ...templateKeyPattern
          .allMatches(source)
          .map((match) => match.group(1))
          .whereType<String>(),
      ...generalTextKeyPattern
          .allMatches(source)
          .map((match) => match.group(1))
          .whereType<String>(),
    };

    for (final locale in [ClientAppLocale.zu, ClientAppLocale.af]) {
      final configuredKeys = ClientAppLocaleText.generalKeysForLocale(locale);
      final missing =
          usedGeneralKeys
              .where((key) => !configuredKeys.contains(key))
              .toList(growable: false)
            ..sort();
      expect(
        missing,
        isEmpty,
        reason: 'Missing ${locale.name} locale keys: ${missing.join(', ')}',
      );
    }
  });

  test('client app locale maps include all used role keys for all roles', () {
    final source = File('lib/ui/client_app_page.dart').readAsStringSync();
    final roleTextKeyPattern = RegExp(
      r"ClientAppLocaleText\.roleText\(\s*\n?\s*locale: [^\n]+,\s*\n?\s*key: '([^']+)'",
    );
    final usedRoleKeys = roleTextKeyPattern
        .allMatches(source)
        .map((match) => match.group(1))
        .whereType<String>()
        .toSet();

    final expectedRoles = ClientAppViewerRole.values.toSet();
    for (final locale in [ClientAppLocale.zu, ClientAppLocale.af]) {
      final configuredRoleKeys = ClientAppLocaleText.roleKeysForLocale(locale);
      final missingKeys =
          usedRoleKeys
              .where((key) => !configuredRoleKeys.contains(key))
              .toList(growable: false)
            ..sort();
      expect(
        missingKeys,
        isEmpty,
        reason:
            'Missing ${locale.name} role locale keys: ${missingKeys.join(', ')}',
      );

      for (final key in usedRoleKeys) {
        final configuredRoles = ClientAppLocaleText.rolesForLocaleKey(
          locale,
          key,
        );
        final missingRoles =
            expectedRoles
                .where((role) => !configuredRoles.contains(role))
                .map((role) => role.name)
                .toList(growable: false)
              ..sort();
        expect(
          missingRoles,
          isEmpty,
          reason:
              'Missing ${locale.name} role entries for key "$key": ${missingRoles.join(', ')}',
        );
      }
    }
  });

  testWidgets('client app page stays stable on phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: <DispatchEvent>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Client Ops App —'), findsOneWidget);
    expect(find.text('Push Notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('client app page stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: <DispatchEvent>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Client Ops App —'), findsOneWidget);
    expect(find.text('Push Notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('client app page applies staged composer prefill for control', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var consumedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const <DispatchEvent>[],
          viewerRole: ClientAppViewerRole.control,
          initialComposerPrefill: const ClientAppComposerPrefill(
            id: 'agent-prefill-1',
            text: 'Agent staged draft for residents.',
            originalDraftText: 'Agent staged draft for residents.',
            type: ClientAppComposerPrefillType.dispatch,
            commandMessage: 'Agent draft is open for Residents',
            commandDetail:
                'Review this staged client update in the live control composer before sending.',
          ),
          onInitialComposerPrefillConsumed: () {
            consumedCount += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composerField = find.descendant(
      of: find.byKey(const ValueKey('client-chat-composer-command-deck')),
      matching: find.byType(TextField),
    );
    expect(composerField, findsOneWidget);
    expect(
      tester.widget<TextField>(composerField).controller?.text,
      'Agent staged draft for residents.',
    );
    expect(find.text('Agent draft is open for Residents'), findsWidgets);
    expect(consumedCount, 1);

    await tester.pump(const Duration(milliseconds: 1000));
  });

  testWidgets(
    'client app page auto-assists staged control prefills when AI assist is available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: const <DispatchEvent>[],
            viewerRole: ClientAppViewerRole.control,
            initialComposerPrefill: const ClientAppComposerPrefill(
              id: 'agent-prefill-ai-1',
              text: 'Agent staged draft for residents.',
              originalDraftText: 'Agent staged draft for residents.',
              type: ClientAppComposerPrefillType.dispatch,
            ),
            onAiAssistComposerDraft: (
              clientId,
              siteId,
              room,
              currentDraftText,
            ) async {
              return 'AI-assisted staged reply for Residents.';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1000));

      final composerField = find.descendant(
        of: find.byKey(const ValueKey('client-chat-composer-command-deck')),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(composerField).controller?.text,
        'AI-assisted staged reply for Residents.',
      );
    },
  );

  testWidgets(
    'client app page keeps staged control prefills stable when auto AI assist fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: const <DispatchEvent>[],
            viewerRole: ClientAppViewerRole.control,
            initialComposerPrefill: const ClientAppComposerPrefill(
              id: 'agent-prefill-ai-fail-1',
              text: 'Agent staged draft for residents.',
              originalDraftText: 'Agent staged draft for residents.',
              type: ClientAppComposerPrefillType.dispatch,
            ),
            onAiAssistComposerDraft: (
              clientId,
              siteId,
              room,
              currentDraftText,
            ) async {
              throw StateError('assist offline');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1000));

      final composerField = find.descendant(
        of: find.byKey(const ValueKey('client-chat-composer-command-deck')),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(composerField).controller?.text,
        'Agent staged draft for residents.',
      );
      expect(
        find.text('AI assist could not refine this draft right now.'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('client app page can AI assist the live reply composer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late String assistedClientId;
    late String assistedSiteId;
    late String assistedRoom;
    late String assistedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const <DispatchEvent>[],
          viewerRole: ClientAppViewerRole.control,
          onAiAssistComposerDraft: (
            clientId,
            siteId,
            room,
            currentDraftText,
          ) async {
            assistedClientId = clientId;
            assistedSiteId = siteId;
            assistedRoom = room;
            assistedDraft = currentDraftText;
            return 'AI-assisted calm follow-up for the resident thread.';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composerField = find.descendant(
      of: find.byKey(const ValueKey('client-chat-composer-command-deck')),
      matching: find.byType(TextField),
    );
    await tester.enterText(composerField, 'Manual draft from control.');
    final aiAssistAction = find.byKey(
      const ValueKey('client-chat-ai-assist-action'),
    );
    await tester.ensureVisible(aiAssistAction);
    await tester.tap(aiAssistAction);
    await tester.pumpAndSettle();

    expect(assistedClientId, 'CLIENT-001');
    expect(assistedSiteId, 'SITE-SANDTON');
    expect(assistedRoom, 'Residents');
    expect(assistedDraft, 'Manual draft from control.');
    expect(
      tester.widget<TextField>(composerField).controller?.text,
      'AI-assisted calm follow-up for the resident thread.',
    );
    await tester.pump(const Duration(milliseconds: 1000));
  });

  testWidgets(
    'client app page keeps the live composer stable when manual AI assist fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: const <DispatchEvent>[],
            viewerRole: ClientAppViewerRole.control,
            onAiAssistComposerDraft: (
              clientId,
              siteId,
              room,
              currentDraftText,
            ) async {
              throw StateError('assist offline');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final composerField = find.descendant(
        of: find.byKey(const ValueKey('client-chat-composer-command-deck')),
        matching: find.byType(TextField),
      );
      await tester.enterText(composerField, 'Manual draft from control.');
      final aiAssistAction = find.byKey(
        const ValueKey('client-chat-ai-assist-action'),
      );
      await tester.ensureVisible(aiAssistAction);
      await tester.tap(aiAssistAction);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(composerField).controller?.text,
        'Manual draft from control.',
      );
      expect(
        find.text('AI assist could not refine this draft right now.'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'client app page sends dispatch review even when learned approval persistence fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: const <DispatchEvent>[],
            viewerRole: ClientAppViewerRole.control,
            initialComposerPrefill: const ClientAppComposerPrefill(
              id: 'agent-prefill-learning-fail-1',
              text: 'Agent staged draft for residents.',
              originalDraftText: 'Agent staged draft for residents.',
              type: ClientAppComposerPrefillType.dispatch,
            ),
            onRecordApprovedDraftLearning: (originalDraft, approvedDraft) async {
              throw StateError('learning store offline');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final composerField = find.descendant(
        of: find.byKey(const ValueKey('client-chat-composer-command-deck')),
        matching: find.byType(TextField),
      );
      final sendAction = find.byKey(const ValueKey('client-chat-send-action'));
      await tester.ensureVisible(sendAction);
      await tester.tap(sendAction);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(composerField).controller?.text, isEmpty);
      expect(find.text('Agent staged draft for residents.'), findsWidgets);
      expect(
        find.text(
          'Dispatch review sent, but approval-style learning was not saved.',
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('client app page ingests evidence returns into the room lane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? consumedAuditId;

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          initialSelectedRoom: 'Residents',
          events: const <DispatchEvent>[],
          evidenceReturnReceipt: const ClientAppEvidenceReturnReceipt(
            auditId: 'client-room-audit-1',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            label: 'EVIDENCE RETURN',
            headline: 'Returned to the Security Desk lane from evidence.',
            detail:
                'The signed room handoff was verified in the ledger. Keep the same lane open and finish the room reply from here.',
            room: 'Security Desk',
            accent: Color(0xFF22D3EE),
          ),
          onConsumeEvidenceReturnReceipt: (auditId) {
            consumedAuditId = auditId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('client-app-evidence-return-banner')),
      findsOneWidget,
    );
    expect(find.text('EVIDENCE RETURN'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('client-app-evidence-return-banner')),
        matching: find.text('Returned to the Security Desk lane from evidence.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Focus lane: Security Desk'), findsOneWidget);
    expect(
      find.text(
        'The signed room handoff was verified in the ledger. Keep the same lane open and finish the room reply from here.',
      ),
      findsOneWidget,
    );
    expect(consumedAuditId, 'client-room-audit-1');
  });

  testWidgets('client app page shows client comms surfaces', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: [
            IntelligenceReceived(
              eventId: 'intel-1',
              sequence: 1,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 15),
              intelligenceId: 'INT-001',
              provider: 'newsapi.org',
              sourceType: 'news',
              externalId: 'EXT-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Client advisory issued',
              summary:
                  'Residents should be aware of suspicious vehicle scouting.',
              riskScore: 78,
              canonicalHash: 'hash-1',
            ),
            DecisionCreated(
              eventId: 'dispatch-1',
              sequence: 2,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
        ),
      ),
    );

    expect(
      find.text('Client Ops App — CLIENT-001 / SITE-SANDTON'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Push alerts, estate chatrooms, incident visibility, and direct client comms in one operational surface.',
      ),
      findsOneWidget,
    );
    expect(find.text('Conversation Sync: Local cache only'), findsOneWidget);
    expect(
      find.text('Run with local defines: ./scripts/run_onyx_chrome_local.sh'),
      findsOneWidget,
    );
    expect(find.text('Push Notifications'), findsOneWidget);
    expect(find.text('Push Delivery Queue'), findsOneWidget);
    expect(find.text('Push Queue Ready'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-delivery-telemetry-strip')),
      findsOneWidget,
    );
    expect(find.text('Push Sync: standing by'), findsOneWidget);
    expect(find.text('Last Sync: none • Retries: 0'), findsOneWidget);
    expect(find.text('Backend Probe: idle • Last Run: none'), findsOneWidget);
    expect(find.text('Backend Probe History: no runs yet.'), findsOneWidget);
    expect(find.text('Push Sync History: no attempts yet.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-delivery-push-sync-empty-recovery')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('client-delivery-backend-probe-empty-recovery'),
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Retry Push Sync'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Run Backend Probe'), findsNothing);
    expect(
      find.widgetWithText(TextButton, 'Clear Probe History'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('client-comms-workspace-panel-notifications')),
      findsOneWidget,
    );
    expect(find.text('Incident Feed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-incident-command-deck')),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Selected Thread • DISP-001'),
      findsOneWidget,
    );
    expect(find.text('Estate Rooms'), findsWidgets);
    expect(
      find.byKey(const ValueKey('client-comms-workspace-panel-rooms')),
      findsOneWidget,
    );
    expect(find.text('Direct Client Chat'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-comms-workspace-panel-chat')),
      findsOneWidget,
    );
    expect(find.text('Client advisory issued'), findsWidgets);
    expect(find.text('Security response activated'), findsWidgets);
    expect(find.text('Opened'), findsOneWidget);
    expect(find.text('Advisory'), findsWidgets);
    expect(find.text('DISP-001'), findsOneWidget);
    expect(find.text('Dispatch'), findsWidgets);
    expect(find.text('Tap to collapse'), findsOneWidget);
    expect(find.text('Opened • 10:20 UTC'), findsOneWidget);
    final openIncidentButton = find
        .widgetWithText(TextButton, 'Open Incident')
        .first;
    await tester.ensureVisible(openIncidentButton);
    await tester.tap(openIncidentButton);
    await tester.pumpAndSettle();
    expect(find.text('Incident Detail'), findsOneWidget);
    expect(richDetailLine('Reference: DISP-001'), findsOneWidget);
    expect(richDetailLine('Latest Status: Opened'), findsOneWidget);
    expect(richDetailLine('Occurred: 10:20 UTC'), findsOneWidget);
    expect(
      richDetailLine('Headline: Security response activated'),
      findsOneWidget,
    );
    expect(
      richDetailLine('Detail: A response team is moving to Sandton now.'),
      findsOneWidget,
    );
    expect(richDetailLine('Events: 1 event'), findsOneWidget);
    expect(find.text('Thread Milestones'), findsOneWidget);
    expect(find.text('Opened'), findsWidgets);
    expect(find.text('DISP-001'), findsWidgets);
    expect(find.text('Security response activated'), findsWidgets);
    expect(
      find.text('A response team is moving to Sandton now.'),
      findsWidgets,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.campaign_rounded), findsAtLeastNWidgets(2));
    expect(find.byIcon(Icons.flash_on_rounded), findsAtLeastNWidgets(2));
    expect(find.text('Residents'), findsOneWidget);
    expect(find.text('Focus lane: Residents'), findsOneWidget);
    expect(find.text('Showing pending: Residents'), findsOneWidget);
    final bannerScopeToggle = find.byKey(
      const ValueKey('client-room-rail-toggle-scope'),
    );
    expect(
      find.descendant(of: bannerScopeToggle, matching: find.text('Show all')),
      findsOneWidget,
    );
    expect(find.text('ONYX • 10:20 UTC'), findsOneWidget);
    expect(find.text('Unread Alerts'), findsOneWidget);
    expect(find.text('Direct Chat'), findsOneWidget);
    expect(find.text('Client Acks Pending'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-delivery-workspace-status-banner')),
      findsOneWidget,
    );
    final selectedDeliveryCard = find.byKey(
      const ValueKey('client-delivery-workspace-selected-card'),
    );
    expect(selectedDeliveryCard, findsOneWidget);
    expect(
      find.descendant(
        of: selectedDeliveryCard,
        matching: find.text('Client Ack'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: selectedDeliveryCard, matching: find.text('In-app')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: selectedDeliveryCard,
        matching: find.text('10:20 UTC'),
      ),
      findsOneWidget,
    );
    final deliveryQueuePanel = find.byKey(
      const ValueKey('client-delivery-workspace-panel-queue'),
    );
    expect(deliveryQueuePanel, findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-delivery-queue-command-deck')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: deliveryQueuePanel,
        matching: find.text('Resident Seen'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: deliveryQueuePanel, matching: find.text('In-app')),
      findsWidgets,
    );
    expect(
      find.descendant(of: deliveryQueuePanel, matching: find.text('10:15 UTC')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-notifications-command-deck')),
      findsOneWidget,
    );
    expect(find.text('Queued'), findsWidgets);
    expect(find.text('Target: Residents'), findsWidgets);
    expect(find.text('Confirm receipt for Residents'), findsOneWidget);
    expect(find.text('Please share ETA for Residents'), findsOneWidget);
    expect(find.text('Client informed in Residents'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Request ETA for Residents'),
      findsWidgets,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Review Advisory for Residents'),
      findsWidgets,
    );
    expect(
      find.widgetWithText(TextButton, 'Send Advisory to Residents'),
      findsWidgets,
    );
    expect(
      find.text(
        'Give this dispatch reply a quick client review before it goes to Residents.',
      ),
      findsWidgets,
    );
    expect(
      find.widgetWithText(TextButton, 'Review client draft for Residents'),
      findsWidgets,
    );
    expect(find.text('Send secure client update...'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send'), findsOneWidget);
    final notificationPrimaryAction = find
        .widgetWithText(OutlinedButton, 'Request ETA for Residents')
        .first;
    await tester.ensureVisible(notificationPrimaryAction);
    await tester.tap(notificationPrimaryAction);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Please share the latest ETA for security response activated in Residents.',
    );
    final openClientReviewButton = find.widgetWithText(
      TextButton,
      'Review client draft for Residents',
    );
    await tester.ensureVisible(openClientReviewButton.first);
    await tester.tap(openClientReviewButton.first);
    await tester.pump();
    expect(
      find.text('Client review draft is open for Residents'),
      findsOneWidget,
    );
    final clientComposer = tester.widget<TextField>(find.byType(TextField));
    expect(
      clientComposer.controller?.text,
      'Please share the latest ETA for security response activated in Residents.',
    );
    expect(clientComposer.decoration?.fillColor, const Color(0xFFE8F1FF));
    expect(
      (clientComposer.decoration?.enabledBorder as OutlineInputBorder)
          .borderSide
          .color,
      const Color(0xFFB7CDE2),
    );
    await tester.pump(const Duration(milliseconds: 950));
    final reviewAdvisoryButton = find.widgetWithText(
      OutlinedButton,
      'Review Advisory for Residents',
    );
    tester.widget<OutlinedButton>(reviewAdvisoryButton).onPressed!.call();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Advisory reviewed and ready to send to Residents.',
    );
    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'Send Advisory to Residents'),
        )
        .onPressed!
        .call();
    await tester.pump();
    expect(find.text('Advisory sent to Residents'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'View in Thread'), findsOneWidget);
    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'Advisory sent to Residents'),
        )
        .onPressed!
        .call();
    await tester.pump();
    expect(find.text('Latest reply in view'), findsOneWidget);
    expect(
      find.text('Advisory reviewed and ready to send to Residents.'),
      findsAtLeastNWidgets(2),
    );
    await tester.pump(const Duration(milliseconds: 950));
    final advisoryNotificationDecorations = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('Client advisory issued'),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    final advisoryNotificationDecoration = advisoryNotificationDecorations
        .firstWhere(
          (decoration) =>
              decoration.border != null &&
              (decoration.border! as Border).top.color ==
                  const Color(0xFFA85A1F),
        );
    expect(
      (advisoryNotificationDecoration.border! as Border).top.color,
      const Color(0xFFA85A1F),
    );
    final dispatchChatDecorations = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('ONYX • 10:20 UTC'),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    final dispatchChatDecoration = dispatchChatDecorations.firstWhere(
      (decoration) =>
          decoration.border != null &&
          (decoration.border! as Border).top.color == const Color(0xFF2F5F94),
    );
    expect(
      (dispatchChatDecoration.border! as Border).top.color,
      const Color(0xFF2F5F94),
    );
  });

  testWidgets('client app page applies zulu locale scaffold labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          locale: ClientAppLocale.zu,
          events: [],
        ),
      ),
    );

    expect(
      find.text('Uhlelo Lwamakhasimende — CLIENT-001 / SITE-SANDTON'),
      findsOneWidget,
    );
    expect(find.text('Ulimi: isiZulu'), findsOneWidget);
    expect(find.text('Izehlakalo Ezisebenzayo'), findsOneWidget);
    expect(
      find.text('Ukuvumelanisa ingxoxo: i-cache yendawo kuphela'),
      findsOneWidget,
    );
  });

  testWidgets(
    'client app page routes room workspace actions through the new comms shell',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var retryRuns = 0;
      var probeRuns = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: [
              IntelligenceReceived(
                eventId: 'intel-workspace-1',
                sequence: 1,
                version: 1,
                occurredAt: _clientAppOccurredAtUtc(4, 10, 15),
                intelligenceId: 'INT-WS-001',
                provider: 'newsapi.org',
                sourceType: 'news',
                externalId: 'EXT-WS-001',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
                headline: 'Client advisory issued',
                summary: 'Residents should remain alert near the east gate.',
                riskScore: 78,
                canonicalHash: 'hash-ws-1',
              ),
              DecisionCreated(
                eventId: 'dispatch-workspace-1',
                sequence: 2,
                version: 1,
                occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
                dispatchId: 'DISP-001',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
              ),
            ],
            initialManualMessages: [
              ClientAppMessage(
                author: 'Client',
                body: 'Trustees would like the next checkpoint update.',
                occurredAt: _clientAppOccurredAtUtc(4, 10, 25),
                roomKey: 'Trustees',
              ),
            ],
            initialPushQueue: [
              ClientAppPushDeliveryItem(
                messageKey: 'delivery-1',
                title: 'Telegram Sync Retry',
                body: 'Residents push delivery is waiting for operator retry.',
                occurredAt: _clientAppOccurredAtUtc(4, 10, 27),
                targetChannel: ClientAppAcknowledgementChannel.resident,
                priority: true,
                status: ClientPushDeliveryStatus.queued,
              ),
            ],
            pushSyncHistory: [
              ClientPushSyncAttempt(
                occurredAt: _clientAppOccurredAtUtc(4, 10, 28),
                status: 'failed',
                failureReason: 'timeout',
                queueSize: 1,
              ),
            ],
            backendProbeHistory: [
              ClientBackendProbeAttempt(
                occurredAt: _clientAppOccurredAtUtc(4, 10, 29),
                status: 'ok',
              ),
            ],
            onRetryPushSync: () async {
              retryRuns += 1;
            },
            onRunBackendProbe: () async {
              probeRuns += 1;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-comms-workspace-panel-rooms')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-comms-workspace-panel-chat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-comms-workspace-panel-context')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-comms-command-receipt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-comms-focus-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-room-rail-command-deck')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-chat-composer-command-deck')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-delivery-workspace-panel-queue')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-delivery-workspace-panel-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-delivery-workspace-panel-incident')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-delivery-command-receipt')),
        findsOneWidget,
      );

      final trusteesRoom = find.byKey(const ValueKey('client-room-Trustees'));
      await tester.ensureVisible(trusteesRoom);
      await tester.tap(trusteesRoom);
      await tester.pumpAndSettle();
      expect(find.text('Focus lane: Trustees'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('client-room-rail-open-thread')),
        findsOneWidget,
      );

      final recommendedDraftAction = find.byKey(
        const ValueKey('client-chat-command-deck-primary-action'),
      );
      await tester.ensureVisible(recommendedDraftAction);
      await tester.tap(recommendedDraftAction);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Trustee review requested for Trustees',
      );

      final toggleScope = find.byKey(
        const ValueKey('client-room-rail-toggle-scope'),
      );
      await tester.ensureVisible(toggleScope);
      await tester.tap(toggleScope);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: toggleScope, matching: find.text('Show pending')),
        findsOneWidget,
      );

      final focusComposerAction = find.byKey(
        const ValueKey('client-room-rail-focus-composer'),
      );
      await tester.ensureVisible(focusComposerAction);
      await tester.tap(focusComposerAction);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isTrue,
      );

      final openThreadAction = find.byKey(
        const ValueKey('client-room-rail-open-thread'),
      );
      await tester.ensureVisible(openThreadAction);
      await tester.tap(openThreadAction);
      await tester.pumpAndSettle();
      expect(find.text('Incident Detail'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.textContaining('incident thread.'), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);

      final deliveryItem = find.byKey(
        const ValueKey('client-delivery-queue-item-delivery-1'),
      );
      await tester.ensureVisible(deliveryItem);
      await tester.tap(deliveryItem);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('client-delivery-workspace-selected-card'),
          ),
          matching: find.text('Telegram Sync Retry'),
        ),
        findsOneWidget,
      );

      final retrySyncAction = find.byKey(
        const ValueKey('client-delivery-telemetry-retry-sync'),
      );
      await tester.ensureVisible(retrySyncAction);
      await tester.tap(retrySyncAction);
      await tester.pump();
      expect(retryRuns, 1);

      final runProbeAction = find.byKey(
        const ValueKey('client-delivery-telemetry-run-probe'),
      );
      await tester.ensureVisible(runProbeAction);
      await tester.tap(runProbeAction);
      await tester.pump();
      expect(probeRuns, 1);
    },
  );

  testWidgets(
    'client app page pins empty incident handoff feedback in the desktop rails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: <DispatchEvent>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-comms-command-receipt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-delivery-command-receipt')),
        findsOneWidget,
      );

      final openThreadAction = find.byKey(
        const ValueKey('client-comms-open-thread'),
      );
      await tester.ensureVisible(openThreadAction);
      await tester.tap(openThreadAction);
      await tester.pumpAndSettle();

      expect(
        find.text('No incident thread is ready for this lane yet.'),
        findsWidgets,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'client app delivery workspace empty states expose recovery pivots',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var retryRuns = 0;
      var probeRuns = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: const <DispatchEvent>[],
            onRetryPushSync: () async {
              retryRuns += 1;
            },
            onRunBackendProbe: () async {
              probeRuns += 1;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-delivery-queue-empty-recovery')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-delivery-selected-empty-recovery')),
        findsOneWidget,
      );

      final retryAction = find.byKey(
        const ValueKey('client-delivery-recovery-retry-sync'),
      );
      await tester.ensureVisible(retryAction.first);
      await tester.tap(retryAction.first);
      await tester.pump();
      expect(retryRuns, 1);

      final probeAction = find.byKey(
        const ValueKey('client-delivery-recovery-run-probe'),
      );
      await tester.ensureVisible(probeAction.first);
      await tester.tap(probeAction.first);
      await tester.pump();
      expect(probeRuns, 1);

      final openThreadAction = find.byKey(
        const ValueKey('client-delivery-recovery-open-thread'),
      );
      await tester.ensureVisible(openThreadAction.first);
      await tester.tap(openThreadAction.first);
      await tester.pumpAndSettle();

      expect(
        find.text('No incident thread is ready for this lane yet.'),
        findsWidgets,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'client app incident workspace empty state exposes recovery pivots',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: <DispatchEvent>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final recoveryDeck = find.byKey(
        const ValueKey('client-incident-feed-empty-recovery'),
      );
      expect(recoveryDeck, findsOneWidget);

      final toggleScopeAction = find.byKey(
        const ValueKey('client-incident-feed-empty-toggle-scope'),
      );
      expect(
        find.descendant(of: toggleScopeAction, matching: find.text('Show all')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('client-incident-feed-empty-open-first')),
      );
      await tester.tap(
        find.byKey(const ValueKey('client-incident-feed-empty-open-first')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No incident thread is ready for this lane yet.'),
        findsWidgets,
      );

      await tester.ensureVisible(toggleScopeAction);
      await tester.tap(toggleScopeAction);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: toggleScopeAction,
          matching: find.text('Show pending'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'client app communications empty recoveries expose scoped pivots',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: <DispatchEvent>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-notifications-empty-recovery')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-chat-empty-recovery')),
        findsOneWidget,
      );

      final notificationsScopeToggle = find.byKey(
        const ValueKey('client-notifications-empty-toggle-scope'),
      );
      await tester.ensureVisible(notificationsScopeToggle);
      await tester.tap(notificationsScopeToggle);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: notificationsScopeToggle,
          matching: find.text('Show pending'),
        ),
        findsOneWidget,
      );

      final chatOpenThread = find.byKey(
        const ValueKey('client-chat-empty-open-thread'),
      );
      await tester.ensureVisible(chatOpenThread);
      await tester.tap(chatOpenThread);
      await tester.pumpAndSettle();

      expect(
        find.text('No incident thread is ready for this lane yet.'),
        findsWidgets,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('client app page restores and emits client draft state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    ClientAppViewerRole? emittedRole;
    String? emittedRoom;
    Map<String, bool> emittedShowAllByRole = const {};
    Map<String, String> emittedSelectedIncidentByRole = const {};
    Map<String, String> emittedExpandedIncidentByRole = const {};
    Map<String, bool> emittedTouchedIncidentByRole = const {};
    Map<String, String> emittedFocusedIncidentByRole = const {};
    List<ClientAppMessage> emittedMessages = const [];
    List<ClientAppAcknowledgement> acknowledgements = const [];

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const [],
          initialSelectedRoom: 'Trustees',
          initialSelectedIncidentReferenceByRole: const {
            'client': 'DISP-SELECTED',
            'control': 'DISP-CONTROL-SELECTED',
          },
          initialExpandedIncidentReferenceByRole: const {
            'client': 'DISP-RESTORED',
            'control': 'DISP-CONTROL',
          },
          initialHasTouchedIncidentExpansionByRole: const {
            'client': true,
            'control': true,
          },
          initialFocusedIncidentReferenceByRole: const {
            'client': 'DISP-FOCUS',
            'control': 'DISP-CONTROL-FOCUS',
          },
          initialManualMessages: [
            ClientAppMessage(
              author: 'Client',
              body: 'Please confirm gate team status.',
              occurredAt: _clientAppOccurredAtUtc(4, 10, 25),
              roomKey: 'Trustees',
              viewerRole: 'client',
            ),
          ],
          onClientStateChanged:
              (
                viewerRole,
                selectedRoomByRole,
                showAllRoomItemsByRole,
                selectedIncidentReferenceByRole,
                expandedIncidentReferenceByRole,
                hasTouchedIncidentExpansionByRole,
                focusedIncidentReferenceByRole,
                messages,
                emittedAcks,
              ) {
                emittedRole = viewerRole;
                emittedRoom =
                    selectedRoomByRole[ClientAppViewerRole.client.name];
                emittedShowAllByRole = showAllRoomItemsByRole;
                emittedSelectedIncidentByRole = selectedIncidentReferenceByRole;
                emittedExpandedIncidentByRole = expandedIncidentReferenceByRole;
                emittedTouchedIncidentByRole =
                    hasTouchedIncidentExpansionByRole;
                emittedFocusedIncidentByRole = focusedIncidentReferenceByRole;
                emittedMessages = messages;
                acknowledgements = emittedAcks;
              },
        ),
      ),
    );

    expect(find.text('Focus lane: Trustees'), findsOneWidget);
    expect(find.text('Client update'), findsOneWidget);
    expect(find.text('Trustees'), findsWidgets);
    expect(find.text('Please confirm gate team status.'), findsWidgets);
    expect(find.text('Client • Trustees • 10:25 UTC'), findsOneWidget);
    expect(find.text('Incident Type'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Update'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Advisory'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Closure'), findsOneWidget);
    expect(find.text('Ready: Update'), findsOneWidget);

    final advisoryModeButton = find.widgetWithText(OutlinedButton, 'Advisory');
    await tester.ensureVisible(advisoryModeButton);
    await tester.tap(advisoryModeButton);
    await tester.pump();
    expect(find.text('Ready: Advisory'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Send Advisory to Trustees'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      'Residents updated on officer arrival.',
    );
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Send Advisory to Trustees'),
        )
        .onPressed!
        .call();
    await tester.pump();

    expect(emittedRoom, 'Trustees');
    expect(emittedRole, ClientAppViewerRole.client);
    expect(emittedShowAllByRole[ClientAppViewerRole.client.name], isFalse);
    expect(
      emittedSelectedIncidentByRole[ClientAppViewerRole.client.name],
      'DISP-SELECTED',
    );
    expect(
      emittedSelectedIncidentByRole[ClientAppViewerRole.control.name],
      'DISP-CONTROL-SELECTED',
    );
    expect(
      emittedExpandedIncidentByRole[ClientAppViewerRole.client.name],
      'DISP-RESTORED',
    );
    expect(
      emittedExpandedIncidentByRole[ClientAppViewerRole.control.name],
      'DISP-CONTROL',
    );
    expect(
      emittedTouchedIncidentByRole[ClientAppViewerRole.client.name],
      isTrue,
    );
    expect(
      emittedFocusedIncidentByRole[ClientAppViewerRole.client.name],
      'DISP-FOCUS',
    );
    expect(
      emittedFocusedIncidentByRole[ClientAppViewerRole.control.name],
      'DISP-CONTROL-FOCUS',
    );
    expect(emittedMessages, hasLength(2));
    expect(acknowledgements, isEmpty);
    expect(emittedMessages.first.body, 'Residents updated on officer arrival.');
    expect(emittedMessages.first.roomKey, 'Trustees');
    expect(emittedMessages.first.viewerRole, 'client');
    expect(emittedMessages.first.incidentStatusLabel, 'Advisory');
    expect(
      find.text('Residents updated on officer arrival.'),
      findsAtLeastNWidgets(2),
    );
  });

  testWidgets('chat source filters isolate telegram messages', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const [],
          initialManualMessages: [
            ClientAppMessage(
              author: 'Client',
              body: 'Internal update from client lane.',
              occurredAt: _clientAppOccurredAtUtc(4, 10, 25),
              roomKey: 'Residents',
              viewerRole: 'client',
              messageSource: 'in_app',
              messageProvider: 'in_app',
            ),
            ClientAppMessage(
              author: 'ONYX AI',
              body: 'Telegram response generated for client.',
              occurredAt: _clientAppOccurredAtUtc(4, 10, 26),
              roomKey: 'Residents',
              viewerRole: 'client',
              messageSource: 'telegram',
              messageProvider: 'openai',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All Sources'), findsOneWidget);
    expect(find.text('In-App'), findsWidgets);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Internal update from client lane.'), findsWidgets);
    expect(find.text('Client • Residents • 10:25 UTC'), findsOneWidget);
    expect(find.text('Telegram response generated for client.'), findsWidgets);
    expect(find.text('ONYX AI • Residents • 10:26 UTC'), findsOneWidget);

    final telegramChip = find.widgetWithText(ChoiceChip, 'Telegram');
    await tester.ensureVisible(telegramChip);
    await tester.tap(telegramChip);
    await tester.pumpAndSettle();

    expect(find.text('Client • Residents • 10:25 UTC'), findsNothing);
    expect(find.text('Internal update from client lane.'), findsNothing);
    expect(find.text('ONYX AI • Residents • 10:26 UTC'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All Sources'));
    await tester.pumpAndSettle();

    expect(find.text('Client • Residents • 10:25 UTC'), findsOneWidget);
    expect(find.text('ONYX AI • Residents • 10:26 UTC'), findsOneWidget);
  });

  testWidgets('client app acknowledges ONYX updates and emits state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    List<ClientAppAcknowledgement> acknowledgements = const [];

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: [
            DecisionCreated(
              eventId: 'dispatch-1',
              sequence: 2,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
          onClientStateChanged:
              (
                viewerRole,
                selectedRoomByRole,
                showAllRoomItemsByRole,
                selectedIncidentReferenceByRole,
                expandedIncidentReferenceByRole,
                hasTouchedIncidentExpansionByRole,
                focusedIncidentReferenceByRole,
                messages,
                emittedAcks,
              ) {
                acknowledgements = emittedAcks;
              },
        ),
      ),
    );

    final clientAckAction = find.widgetWithText(TextButton, 'Client Ack');
    expect(clientAckAction, findsWidgets);
    final selectedDeliveryCard = find.byKey(
      const ValueKey('client-delivery-workspace-selected-card'),
    );
    expect(selectedDeliveryCard, findsOneWidget);
    expect(
      find.descendant(
        of: selectedDeliveryCard,
        matching: find.text('Client Ack'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: selectedDeliveryCard, matching: find.text('In-app')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: selectedDeliveryCard,
        matching: find.text('10:20 UTC'),
      ),
      findsOneWidget,
    );
    expect(find.text('Queued'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Control Ack'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Resident Seen'), findsNothing);
    await tester.ensureVisible(clientAckAction.first);
    await tester.tap(clientAckAction.first);
    await tester.pump();

    expect(acknowledgements, hasLength(1));
    expect(
      acknowledgements.first.channel,
      ClientAppAcknowledgementChannel.client,
    );
    expect(acknowledgements.first.acknowledgedBy, 'Client');
    expect(find.textContaining('Client Ack by Client at'), findsNWidgets(2));
    expect(
      find.descendant(
        of: selectedDeliveryCard,
        matching: find.text('Delivered'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('control role only shows control acknowledgement action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    List<ClientAppMessage> emittedMessages = const [];

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          viewerRole: ClientAppViewerRole.control,
          events: [
            IntelligenceReceived(
              eventId: 'intel-1',
              sequence: 1,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 15),
              intelligenceId: 'INT-001',
              provider: 'newsapi.org',
              sourceType: 'news',
              externalId: 'EXT-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Control advisory issued',
              summary: 'Maintain monitoring on the resident lane.',
              riskScore: 72,
              canonicalHash: 'hash-control',
            ),
            DecisionCreated(
              eventId: 'dispatch-1',
              sequence: 2,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
          onClientStateChanged:
              (
                viewerRole,
                selectedRoomByRole,
                showAllRoomItemsByRole,
                selectedIncidentReferenceByRole,
                expandedIncidentReferenceByRole,
                hasTouchedIncidentExpansionByRole,
                focusedIncidentReferenceByRole,
                messages,
                emittedAcks,
              ) {
                emittedMessages = messages;
              },
        ),
      ),
    );

    expect(find.widgetWithText(TextButton, 'Client Ack'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Control Ack'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Resident Seen'), findsNothing);
    expect(find.text('Open Alerts'), findsOneWidget);
    expect(find.text('Active Incident Timeline'), findsOneWidget);
    expect(find.text('Desk Thread'), findsOneWidget);
    expect(find.text('Control Acks Pending'), findsOneWidget);
    expect(find.text('Control Alerts'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-comms-workspace-panel-notifications')),
      findsOneWidget,
    );
    expect(find.text('Audience Channels'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-comms-workspace-panel-rooms')),
      findsOneWidget,
    );
    expect(find.text('Desk Coordination Thread'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-comms-workspace-panel-chat')),
      findsOneWidget,
    );
    expect(find.text('Resident Feed'), findsOneWidget);
    expect(find.text('Trustee Board'), findsOneWidget);
    expect(find.text('Desk Ops'), findsOneWidget);
    expect(find.text('Focus lane: Resident Feed'), findsOneWidget);
    expect(find.text('Showing pending: Resident Feed'), findsOneWidget);
    expect(find.text('Target: Resident Feed'), findsWidgets);
    expect(
      find.text('Resident feed monitored for Resident Feed'),
      findsOneWidget,
    );
    expect(
      find.text('Community alert issued for Resident Feed'),
      findsOneWidget,
    );
    expect(
      find.text('Awaiting resident acknowledgement for Resident Feed'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Open Dispatch for Resident Feed'),
      findsWidgets,
    );
    expect(find.widgetWithText(TextButton, 'Send Now'), findsNothing);
    expect(
      find.text(
        'Give this dispatch reply a quick review before it goes to Resident Feed.',
      ),
      findsWidgets,
    );
    expect(
      find.widgetWithText(
        TextButton,
        'Review dispatch draft for Resident Feed',
      ),
      findsWidgets,
    );
    expect(find.text('Log a resident-lane control update...'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Log Resident Update'),
      findsOneWidget,
    );
    expect(find.text('Ready: Update'), findsOneWidget);

    final openDispatchDraftButton = find.widgetWithText(
      TextButton,
      'Review dispatch draft for Resident Feed',
    );
    await tester.ensureVisible(openDispatchDraftButton.first);
    await tester.tap(openDispatchDraftButton.first);
    await tester.pump();
    expect(
      find.text('Dispatch draft is open for Resident Feed'),
      findsOneWidget,
    );
    expect(find.text('Ready: Dispatch review'), findsOneWidget);
    expect(
      find.widgetWithText(
        FilledButton,
        'Log Dispatch Review for Resident Feed',
      ),
      findsOneWidget,
    );
    final controlComposer = tester.widget<TextField>(find.byType(TextField));
    expect(
      controlComposer.controller?.text,
      'Control is checking the dispatch response for Resident Feed now.',
    );
    expect(controlComposer.decoration?.fillColor, const Color(0xFFE8F1FF));
    await tester.pump(const Duration(milliseconds: 950));
    final deskOpsRoomTile = find.ancestor(
      of: find.text('Desk Ops').first,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(deskOpsRoomTile.first).onTap!.call();
    await tester.pump();

    expect(find.text('Focus lane: Desk Ops'), findsOneWidget);
    expect(find.text('Showing pending: Desk Ops'), findsOneWidget);
    expect(find.text('Desk investigating in Desk Ops'), findsOneWidget);
    expect(find.text('Control team notified for Desk Ops'), findsOneWidget);
    expect(
      find.text('Awaiting guard confirmation for Desk Ops'),
      findsOneWidget,
    );
    expect(find.text('Resident feed monitored'), findsNothing);
    expect(find.text('Log a desk coordination update...'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Log Dispatch Review for Desk Ops'),
      findsOneWidget,
    );

    tester
        .widget<OutlinedButton>(
          find.widgetWithText(
            OutlinedButton,
            'Control team notified for Desk Ops',
          ),
        )
        .onPressed!
        .call();
    await tester.pump();
    expect(
      find.text('Control team notified for Desk Ops'),
      findsAtLeastNWidgets(1),
    );
    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'Log Advisory Now for Desk Ops'),
        )
        .onPressed!
        .call();
    await tester.pump();
    expect(find.text('Advisory log posted to Desk Ops'), findsOneWidget);
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'View Log Entry'))
        .onPressed!
        .call();
    await tester.pump();
    expect(find.text('Latest log entry in view'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 950));

    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Log Desk Update'),
        )
        .onPressed!
        .call();
    await tester.pump();

    expect(emittedMessages.first.author, 'Control');
    expect(emittedMessages.first.roomKey, 'Security Desk');
    expect(emittedMessages.first.viewerRole, 'control');
    expect(
      emittedMessages.any(
        (message) =>
            message.incidentStatusLabel == 'Advisory' &&
            message.body ==
                'Control is shaping the advisory update for Desk Ops.',
      ),
      isTrue,
    );
    expect(find.text('Control team notified for Desk Ops'), findsWidgets);

    final residentViewChip = find.ancestor(
      of: find.text('Resident View'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(residentViewChip.first).onTap!.call();
    await tester.pump();

    expect(
      find.text('Resident Estate Feed — CLIENT-001 / SITE-SANDTON'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Resident-facing safety updates, acknowledgement prompts, and community incident awareness.',
      ),
      findsOneWidget,
    );
    expect(find.text('Safety Updates'), findsOneWidget);
    expect(find.text('Safety Timeline'), findsOneWidget);
    expect(find.text('Estate Channels'), findsOneWidget);
    expect(find.text('Resident Message Thread'), findsOneWidget);
    expect(find.text('New Safety Alerts'), findsOneWidget);
    expect(find.text('Message Thread'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Estate Admin'), findsOneWidget);
    expect(find.text('Security Team'), findsOneWidget);
    expect(find.text('Focus lane: Community'), findsOneWidget);
    expect(find.text('Showing pending: Community'), findsOneWidget);
    expect(find.text('Safety Thread DISP-001 • 1 update'), findsOneWidget);
    expect(find.text('Collapse Safety'), findsOneWidget);
    expect(find.text('Security responding at Sandton'), findsNWidgets(2));
    expect(find.text('Updated 10:20 UTC'), findsOneWidget);
    expect(
      find.text('Security has been notified and updates are in progress.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Control Ack'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Resident Seen'), findsWidgets);
    expect(find.text('Resident Seen Pending'), findsOneWidget);
  });

  testWidgets('resident advisory actions use resident-specific labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          viewerRole: ClientAppViewerRole.resident,
          events: [
            IntelligenceReceived(
              eventId: 'intel-1',
              sequence: 1,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 15),
              intelligenceId: 'INT-001',
              provider: 'newsapi.org',
              sourceType: 'news',
              externalId: 'EXT-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
              headline: 'Resident advisory issued',
              summary: 'Residents should remain alert near the east gate.',
              riskScore: 78,
              canonicalHash: 'hash-1',
            ),
          ],
        ),
      ),
    );

    expect(
      find.widgetWithText(
        OutlinedButton,
        'Draft Community Alert for Community',
      ),
      findsWidgets,
    );
    expect(
      find.widgetWithText(TextButton, 'Post Advisory to Community'),
      findsWidgets,
    );
    final draftCommunityAlertButton = find.byKey(
      const ValueKey('client-delivery-open-draft'),
    );
    await tester.ensureVisible(draftCommunityAlertButton);
    await tester.tap(draftCommunityAlertButton);
    await tester.pump();
    final residentComposer = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(
      residentComposer.controller?.text,
      'Resident is preparing a community alert for Community.',
    );
    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'Post Advisory to Community').first,
        )
        .onPressed!
        .call();
    await tester.pump();
    expect(find.text('Community alert posted to Community'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'View Resident Reply'),
      findsWidgets,
    );
    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'View Resident Reply').first,
        )
        .onPressed!
        .call();
    await tester.pump();
    expect(find.text('Latest resident reply in view'), findsOneWidget);
    expect(
      find.text('Resident is preparing a community alert for Community.'),
      findsWidgets,
    );
    await tester.pump(const Duration(milliseconds: 950));
  });

  testWidgets('control view uses role-specific empty states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          backendSyncEnabled: true,
          viewerRole: ClientAppViewerRole.control,
          events: const [],
        ),
      ),
    );

    expect(
      find.text('Conversation Sync: Supabase + local fallback'),
      findsOneWidget,
    );
    expect(
      find.text('Control alerts are quiet in this lane right now.'),
      findsOneWidget,
    );
    expect(
      find.text('Desk coordination is quiet in this lane right now.'),
      findsOneWidget,
    );
    expect(find.text('Lane voice: Auto'), findsOneWidget);
    final noThreadButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Choose a Thread'),
    );
    expect(noThreadButton.onPressed, isNotNull);

    final chooseThreadAction = find.widgetWithText(
      TextButton,
      'Choose a Thread',
    );
    await tester.ensureVisible(chooseThreadAction);
    await tester.tap(chooseThreadAction);
    await tester.pumpAndSettle();

    expect(
      find.text('No incident thread is ready for this lane yet.'),
      findsWidgets,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('client app restores show-all room override', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          initialSelectedRoom: 'Security Desk',
          initialShowAllRoomItems: true,
          events: [
            DecisionCreated(
              eventId: 'dispatch-1',
              sequence: 2,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Focus lane: Security Desk'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-comms-workspace-panel-notifications')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-comms-workspace-panel-rooms')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-comms-workspace-panel-chat')),
      findsOneWidget,
    );
    expect(find.text('Target (current lane): Security Desk'), findsWidgets);
    final restoredScopeToggle = find.byKey(
      const ValueKey('client-room-rail-toggle-scope'),
    );
    expect(
      find.descendant(
        of: restoredScopeToggle,
        matching: find.text('Show pending'),
      ),
      findsOneWidget,
    );
    expect(find.text('Security response activated'), findsWidgets);
  });

  testWidgets('control lane shows and updates the pinned voice profile', (
    tester,
  ) async {
    String? updatedSignal;

    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          viewerRole: ClientAppViewerRole.control,
          laneVoiceProfileLabel: 'Reassuring',
          laneVoiceProfileSignal: 'reassurance-forward',
          onSetLaneVoiceProfile: (profileSignal) async {
            updatedSignal = profileSignal;
          },
          events: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('client-lane-voice-strip')),
      findsOneWidget,
    );
    expect(find.text('Lane voice: Reassuring'), findsOneWidget);
    expect(
      find.text(
        'Shape ONYX toward the tone this lane needs before you review or send the next reply.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(ChoiceChip, 'Auto'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Concise'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Reassuring'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Validation-heavy'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Concise'));
    await tester.pumpAndSettle();

    expect(updatedSignal, 'concise-updates');
  });

  testWidgets('control lane shows learned approval status and can clear it', (
    tester,
  ) async {
    bool cleared = false;

    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          viewerRole: ClientAppViewerRole.control,
          laneVoiceProfileLabel: 'Reassuring',
          laneVoiceProfileSignal: 'reassurance-forward',
          learnedApprovalStyleCount: 2,
          learnedApprovalStyleExample:
              'Control is checking the latest position now and will share the next confirmed step shortly.',
          onClearLearnedLaneStyle: () async {
            cleared = true;
          },
          events: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('ONYX mode: Pinned voice + learned approvals'),
      findsOneWidget,
    );
    expect(find.text('Pinned voice Reassuring'), findsOneWidget);
    expect(find.text('Learned approvals (2)'), findsOneWidget);
    expect(find.text('Learned approval style'), findsOneWidget);
    expect(
      find.textContaining(
        'Control is checking the latest position now and will share the next confirmed step shortly.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Clear Learned Style'),
      findsOneWidget,
    );

    final clearLearnedStyleButton = find.widgetWithText(
      OutlinedButton,
      'Clear Learned Style',
    );
    await tester.ensureVisible(clearLearnedStyleButton);
    await tester.tap(clearLearnedStyleButton);
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
  });

  testWidgets('control draft actions reflect pinned lane voice immediately', (
    tester,
  ) async {
    String laneVoiceLabel = 'Auto';
    String laneVoiceSignal = '';

    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return ClientAppPage(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              viewerRole: ClientAppViewerRole.control,
              laneVoiceProfileLabel: laneVoiceLabel,
              laneVoiceProfileSignal: laneVoiceSignal,
              learnedApprovalStyleCount: 1,
              learnedApprovalStyleExample:
                  'Control is checking the latest position now and will share the next confirmed step shortly.',
              onSetLaneVoiceProfile: (profileSignal) async {
                setState(() {
                  laneVoiceSignal = profileSignal ?? '';
                  laneVoiceLabel = switch (laneVoiceSignal) {
                    'concise-updates' => 'Concise',
                    'reassurance-forward' => 'Reassuring',
                    'validation-heavy' => 'Validation-heavy',
                    _ => 'Auto',
                  };
                });
              },
              events: [
                DecisionCreated(
                  eventId: 'dispatch-voice-1',
                  sequence: 1,
                  version: 1,
                  occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
                  dispatchId: 'DISP-VOICE-1',
                  clientId: 'CLIENT-001',
                  regionId: 'REGION-GAUTENG',
                  siteId: 'SITE-SANDTON',
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final validationHeavyChip = find.widgetWithText(
      ChoiceChip,
      'Validation-heavy',
    );
    await tester.ensureVisible(validationHeavyChip);
    await tester.tap(validationHeavyChip);
    await tester.pumpAndSettle();

    expect(find.text('Lane voice: Validation-heavy'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextButton,
        'Review dispatch draft for Resident Feed • Validation-heavy',
      ),
      findsOneWidget,
    );

    final reviewButton = find.widgetWithText(
      TextButton,
      'Review dispatch draft for Resident Feed • Validation-heavy',
    );
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    await tester.pump();

    expect(
      find.text('Dispatch draft is open for Resident Feed • Validation-heavy'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Control is checking the dispatch response for Resident Feed now and will share the next verified position update.',
    );
    expect(find.text('Uses learned approval style'), findsOneWidget);
    expect(
      find.textContaining('This prefill is leaning on approved lane wording'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Latest learned pattern: "Control is checking the latest position now and will share the next confirmed step shortly."',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 950));
  });

  testWidgets('room selection filters to pending items for that audience', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final occurredAt = _clientAppOccurredAtUtc(4, 10, 20);
    final messageKey =
        'system:${occurredAt.millisecondsSinceEpoch}:'
        'Security response activated:'
        'A response team is moving to Sandton now.';

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          initialSelectedRoom: 'Security Desk',
          initialAcknowledgements: [
            ClientAppAcknowledgement(
              messageKey: messageKey,
              channel: ClientAppAcknowledgementChannel.control,
              acknowledgedBy: 'Control',
              acknowledgedAt: _clientAppOccurredAtUtc(4, 10, 21),
            ),
          ],
          events: [
            DecisionCreated(
              eventId: 'dispatch-1',
              sequence: 2,
              version: 1,
              occurredAt: occurredAt,
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Focus lane: Security Desk'), findsOneWidget);
    expect(find.text('Showing pending: Security Desk'), findsOneWidget);
    final emptyNotificationsScopeToggle = find.byKey(
      const ValueKey('client-notifications-empty-toggle-scope'),
    );
    expect(
      find.descendant(
        of: emptyNotificationsScopeToggle,
        matching: find.text('Show all'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Client notifications will appear here when this lane updates.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Direct chat will appear here once this lane starts talking.'),
      findsOneWidget,
    );

    final notificationsScopeToggle = find.byKey(
      const ValueKey('client-notifications-empty-toggle-scope'),
    );
    await tester.ensureVisible(notificationsScopeToggle);
    await tester.tap(notificationsScopeToggle);
    await tester.pumpAndSettle();

    expect(find.text('Target (current lane): Security Desk'), findsWidgets);
    final liveScopeToggle = find.byKey(
      const ValueKey('client-room-rail-toggle-scope'),
    );
    expect(
      find.descendant(of: liveScopeToggle, matching: find.text('Show pending')),
      findsOneWidget,
    );
    expect(find.text('Security response activated'), findsWidgets);
    expect(find.text('ONYX • 10:20 UTC'), findsOneWidget);

    final residentsRoom = find.text('Residents').first;
    await tester.ensureVisible(residentsRoom);
    await tester.tap(residentsRoom);
    await tester.pump();

    expect(find.text('Focus lane: Residents'), findsOneWidget);
    expect(find.text('Showing pending: Residents'), findsOneWidget);
    final roomRailScopeToggle = find.byKey(
      const ValueKey('client-room-rail-toggle-scope'),
    );
    expect(
      find.descendant(of: roomRailScopeToggle, matching: find.text('Show all')),
      findsOneWidget,
    );
    expect(find.text('Security response activated'), findsWidgets);
    expect(find.text('ONYX • 10:20 UTC'), findsOneWidget);
    expect(find.textContaining('Control Ack by Control at'), findsNWidgets(2));
  });

  testWidgets('incident feed groups multiple milestones by reference', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: [
            ResponseArrived(
              eventId: 'arrived-1',
              sequence: 2,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 25),
              dispatchId: 'DISP-001',
              guardId: 'GUARD-7',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            DecisionCreated(
              eventId: 'dispatch-1',
              sequence: 1,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
        ),
      ),
    );

    expect(find.text('DISP-001'), findsWidgets);
    expect(find.text('2 events'), findsOneWidget);
    expect(find.text('Responder on site'), findsWidgets);
    expect(find.text('Tap to collapse'), findsOneWidget);
    expect(find.text('On Site • 10:25 UTC'), findsOneWidget);
    expect(find.text('Opened • 10:20 UTC'), findsOneWidget);

    final openIncidentAction = find.widgetWithText(TextButton, 'Open Incident');
    await tester.ensureVisible(openIncidentAction);
    await tester.tap(openIncidentAction);
    await tester.pumpAndSettle();
    expect(find.text('Incident Detail'), findsOneWidget);
    expect(find.text('2 events'), findsWidgets);
    expect(find.text('Responder on site'), findsWidgets);
    expect(find.text('Security response activated'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('control incident detail uses control labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          viewerRole: ClientAppViewerRole.control,
          events: [
            DecisionCreated(
              eventId: 'dispatch-1',
              sequence: 1,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
        ),
      ),
    );

    final openThreadButton = find.widgetWithText(TextButton, 'Open Thread');
    await tester.ensureVisible(openThreadButton);
    await tester.tap(openThreadButton);
    await tester.pumpAndSettle();

    expect(find.text('Dispatched'), findsOneWidget);
    expect(find.text('Thread DISP-001 • 1 milestone'), findsOneWidget);
    expect(find.text('Active Thread'), findsOneWidget);
    expect(find.text('Expanded Thread'), findsOneWidget);
    expect(find.text('Open Thread'), findsWidgets);
    expect(
      find.widgetWithText(TextButton, 'Active Thread • DISP-001'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Choose a Thread'), findsNothing);
    expect(find.text('Logged 10:20 UTC'), findsOneWidget);
    expect(find.text('Control Incident Thread'), findsOneWidget);
    expect(find.text('Collapse Thread'), findsOneWidget);
    expect(find.text('Milestone: Dispatched • Logged 10:20 UTC'), findsWidgets);
    final controlIncidentDecorations = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('Thread DISP-001 • 1 milestone'),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    final controlIncidentDecoration = controlIncidentDecorations.firstWhere(
      (decoration) => decoration.color == const Color(0xFFE8F1FF),
    );
    expect(
      (controlIncidentDecoration.border! as Border).top.color,
      const Color(0xFF4A86C7),
    );
    expect(richDetailLine('Dispatch Thread: DISP-001'), findsOneWidget);
    expect(richDetailLine('Latest Milestone: Dispatched'), findsOneWidget);
    expect(richDetailLine('Logged: 10:20 UTC'), findsOneWidget);
    expect(
      richDetailLine('Operational Summary: Security response activated'),
      findsOneWidget,
    );
    expect(
      richDetailLine(
        'Operational Detail: A response team is moving to Sandton now.',
      ),
      findsOneWidget,
    );
    expect(richDetailLine('Timeline Events: 1 milestone'), findsOneWidget);
    expect(find.text('Operational Milestones'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(TextButton, 'Active Thread • DISP-001'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Control Incident Thread'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('incident feed restores the selected expanded thread', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          initialExpandedIncidentReferenceByRole: const {'client': 'DISP-001'},
          initialHasTouchedIncidentExpansionByRole: const {'client': true},
          events: [
            DecisionCreated(
              eventId: 'dispatch-2',
              sequence: 3,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 30),
              dispatchId: 'DISP-002',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            ResponseArrived(
              eventId: 'arrived-1',
              sequence: 2,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 25),
              dispatchId: 'DISP-001',
              guardId: 'GUARD-7',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            DecisionCreated(
              eventId: 'dispatch-1',
              sequence: 1,
              version: 1,
              occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
        ),
      ),
    );

    expect(find.text('DISP-002'), findsOneWidget);
    expect(find.text('DISP-001'), findsWidgets);
    expect(
      find.byKey(const ValueKey('client-incident-command-deck')),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Selected Thread • DISP-001'),
      findsOneWidget,
    );
    expect(find.text('Tap to expand'), findsOneWidget);
    expect(find.text('Tap to collapse'), findsOneWidget);
    expect(find.text('Opened • 10:30 UTC'), findsNothing);
    expect(find.text('On Site • 10:25 UTC'), findsOneWidget);
    expect(find.text('Opened • 10:20 UTC'), findsOneWidget);

    final secondIncidentRow = find.byKey(
      const ValueKey('client-incident-row-DISP-002'),
    );
    await tester.ensureVisible(secondIncidentRow);
    await tester.tap(secondIncidentRow);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextButton, 'Selected Thread • DISP-002'),
      findsOneWidget,
    );
  });

  testWidgets('push sync history rows render when provided', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const [],
          pushSyncHistory: [
            ClientPushSyncAttempt(
              occurredAt: _clientAppOccurredAtUtc(5, 10, 30),
              status: 'failed',
              failureReason: 'timeout',
              queueSize: 2,
            ),
            ClientPushSyncAttempt(
              occurredAt: _clientAppOccurredAtUtc(5, 10, 31),
              status: 'ok',
              queueSize: 0,
            ),
          ],
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('client-delivery-push-sync-history-card')),
      findsOneWidget,
    );
    expect(
      find.textContaining('10:30 UTC • needs review • queue:2 • timeout'),
      findsOneWidget,
    );
    expect(find.textContaining('10:31 UTC • synced • queue:0'), findsOneWidget);
  });

  testWidgets('delivery telemetry empty recovery decks expose command pivots', (
    tester,
  ) async {
    var retryRuns = 0;
    var probeRuns = 0;
    var clearRuns = 0;

    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const [],
          onRetryPushSync: () async {
            retryRuns += 1;
          },
          onRunBackendProbe: () async {
            probeRuns += 1;
          },
          onClearBackendProbeHistory: () async {
            clearRuns += 1;
          },
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('client-delivery-push-sync-empty-recovery')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('client-delivery-backend-probe-empty-recovery'),
      ),
      findsOneWidget,
    );

    final retrySyncAction = find.byKey(
      const ValueKey('client-delivery-push-sync-empty-retry-sync'),
    );
    await tester.ensureVisible(retrySyncAction);
    await tester.tap(retrySyncAction);
    await tester.pump();
    expect(retryRuns, 1);

    final runProbeAction = find.byKey(
      const ValueKey('client-delivery-backend-probe-empty-run-probe'),
    );
    await tester.ensureVisible(runProbeAction);
    await tester.tap(runProbeAction);
    await tester.pump();
    expect(probeRuns, 1);

    final clearProbeAction = find.byKey(
      const ValueKey('client-delivery-backend-probe-empty-clear-history'),
    );
    await tester.ensureVisible(clearProbeAction);
    await tester.tap(clearProbeAction);
    await tester.pumpAndSettle();
    expect(find.text('Clear Probe History?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(clearRuns, 1);
  });

  testWidgets('push sync strip renders telegram health when provided', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const [],
          telegramHealthLabel: 'blocked',
          telegramHealthDetail:
              'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
          telegramFallbackActive: true,
          pushSyncStatusLabel: 'failed',
          pushSyncFailureReason: 'Push sync needs operator review.',
        ),
      ),
    );

    expect(find.text('Telegram: BLOCKED'), findsOneWidget);
    expect(find.text('Telegram fallback is active.'), findsOneWidget);
    expect(
      find.textContaining(
        'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
      ),
      findsOneWidget,
    );
    expect(find.text('Push Sync: needs review'), findsOneWidget);
  });

  testWidgets('push sync strip humanizes provider outcomes when provided', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const [],
          pushSyncStatusLabel: 'degraded',
          pushSyncFailureReason:
              'voip:asterisk staged call for Waterfall command desk.',
          pushSyncHistory: [
            ClientPushSyncAttempt(
              occurredAt: _clientAppOccurredAtUtc(5, 10, 30),
              status: 'sms-fallback-ok',
              failureReason: 'sms:bulksms sent 2/2 after telegram blocked.',
              queueSize: 2,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Push Sync: delivery under watch'), findsOneWidget);
    expect(
      find.textContaining(
        'Failure: Asterisk staged a call for Waterfall command desk.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('10:30 UTC • sms fallback sent • queue:2'),
      findsOneWidget,
    );
    expect(find.textContaining('BulkSMS reached 2/2 contacts'), findsOneWidget);
  });

  testWidgets('backend probe button triggers callback when provided', (
    tester,
  ) async {
    var probeRuns = 0;
    var clearRuns = 0;
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ClientAppPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          events: const [],
          backendProbeStatusLabel: 'ok',
          backendProbeLastRunAtUtc: _clientAppOccurredAtUtc(5, 11, 0),
          backendProbeHistory: [
            ClientBackendProbeAttempt(
              occurredAt: _clientAppOccurredAtUtc(5, 10, 59),
              status: 'failed',
              failureReason: 'network timeout',
            ),
            ClientBackendProbeAttempt(
              occurredAt: _clientAppOccurredAtUtc(5, 11, 0),
              status: 'ok',
            ),
          ],
          onRunBackendProbe: () async {
            probeRuns += 1;
          },
          onClearBackendProbeHistory: () async {
            clearRuns += 1;
          },
        ),
      ),
    );

    expect(
      find.text('Backend Probe: ok • Last Run: 11:00 UTC'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-delivery-backend-probe-history-card')),
      findsOneWidget,
    );
    expect(
      find.textContaining('10:59 UTC • failed • network timeout'),
      findsOneWidget,
    );
    expect(find.textContaining('11:00 UTC • ok'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-delivery-telemetry-run-probe')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-delivery-telemetry-clear-probe')),
      findsOneWidget,
    );
    final runBackendProbeButton = find.byKey(
      const ValueKey('client-delivery-telemetry-run-probe'),
    );
    await tester.ensureVisible(runBackendProbeButton);
    await tester.tap(runBackendProbeButton);
    await tester.pump();
    expect(probeRuns, 1);
    final clearProbeHistoryButton = find.byKey(
      const ValueKey('client-delivery-telemetry-clear-probe'),
    );
    await tester.ensureVisible(clearProbeHistoryButton);
    await tester.tap(clearProbeHistoryButton);
    await tester.pumpAndSettle();
    expect(find.text('Clear Probe History?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(clearRuns, 1);
  });

  testWidgets(
    'client app delivery recovery actions stay pinned when retry or probe callbacks fail',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            events: const [],
            pushSyncStatusLabel: 'degraded',
            pushSyncHistory: [
              ClientPushSyncAttempt(
                occurredAt: _clientAppOccurredAtUtc(5, 10, 58),
                status: 'failed',
                failureReason: 'bridge offline',
                queueSize: 1,
              ),
            ],
            backendProbeStatusLabel: 'failed',
            backendProbeLastRunAtUtc: _clientAppOccurredAtUtc(5, 11, 0),
            backendProbeHistory: [
              ClientBackendProbeAttempt(
                occurredAt: _clientAppOccurredAtUtc(5, 11, 0),
                status: 'failed',
                failureReason: 'network timeout',
              ),
            ],
            onRetryPushSync: () async {
              throw StateError('retry failed');
            },
            onRunBackendProbe: () async {
              throw StateError('probe failed');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final retryAction = find.byKey(
        const ValueKey('client-delivery-telemetry-retry-sync'),
      );
      await tester.ensureVisible(retryAction);
      await tester.tap(retryAction);
      await tester.pump();

      expect(
        find.text('Push sync retry could not complete right now.'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);

      final runProbeAction = find.byKey(
        const ValueKey('client-delivery-telemetry-run-probe'),
      );
      await tester.ensureVisible(runProbeAction);
      await tester.tap(runProbeAction);
      await tester.pump();

      expect(
        find.text('Backend probe could not complete right now.'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no selected incident action opens the first available incident thread',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAppPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            initialHasTouchedIncidentExpansionByRole: const {'client': true},
            events: [
              DecisionCreated(
                eventId: 'dispatch-1',
                sequence: 1,
                version: 1,
                occurredAt: _clientAppOccurredAtUtc(4, 10, 20),
                dispatchId: 'DISP-001',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openFirstAction = find.byKey(
        const ValueKey('incident-feed-open-first-action'),
      );
      expect(openFirstAction, findsOneWidget);
      expect(find.text('Choose an Incident'), findsOneWidget);

      await tester.ensureVisible(openFirstAction);
      await tester.tap(openFirstAction);
      await tester.pumpAndSettle();

      expect(find.text('Incident Detail'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, 'Selected Thread • DISP-001'),
        findsOneWidget,
      );
    },
  );
}
