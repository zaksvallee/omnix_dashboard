import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/ui/client_app_page.dart';

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
      final missing = usedGeneralKeys
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
      final missingKeys = usedRoleKeys
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
        final missingRoles = expectedRoles
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 15),
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 20),
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
    expect(find.text('Push Sync: Push sync idle'), findsOneWidget);
    expect(find.text('Last Sync: none • Retries: 0'), findsOneWidget);
    expect(find.text('Backend Probe: idle • Last Run: none'), findsOneWidget);
    expect(find.text('Backend Probe History: no runs yet.'), findsOneWidget);
    expect(find.text('Push Sync History: no attempts yet.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry Push Sync'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Run Backend Probe'), findsNothing);
    expect(
      find.widgetWithText(TextButton, 'Clear Probe History'),
      findsNothing,
    );
    expect(
      find.text(
        'Alarm triggers, arrivals, closures, and intelligence advisories. Showing pending notifications for Residents.',
      ),
      findsOneWidget,
    );
    expect(find.text('Incident Feed'), findsOneWidget);
    expect(
      find.text(
        'Chronological dispatch, arrival, closure, and advisory milestones.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Selected Thread • DISP-001'),
      findsOneWidget,
    );
    expect(find.text('Estate Rooms'), findsWidgets);
    expect(
      find.text(
        'Residents, trustees, and control channels. Current lane: Residents • lane-pending activity in focus.',
      ),
      findsOneWidget,
    );
    expect(find.text('Direct Client Chat'), findsOneWidget);
    expect(
      find.text(
        'Secure client thread with operational updates. Showing pending thread messages for Residents.',
      ),
      findsOneWidget,
    );
    expect(find.text('Client advisory issued'), findsWidgets);
    expect(find.text('Dispatch created'), findsWidgets);
    expect(find.text('Opened'), findsOneWidget);
    expect(find.text('Advisory'), findsWidgets);
    expect(find.text('DISP-001'), findsOneWidget);
    expect(find.text('Dispatch'), findsWidgets);
    expect(find.text('Tap to collapse'), findsOneWidget);
    expect(find.text('Opened • 10:20 UTC'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Open Incident'));
    await tester.pumpAndSettle();
    expect(find.text('Incident Detail'), findsOneWidget);
    expect(richDetailLine('Reference: DISP-001'), findsOneWidget);
    expect(richDetailLine('Latest Status: Opened'), findsOneWidget);
    expect(richDetailLine('Occurred: 10:20 UTC'), findsOneWidget);
    expect(
      richDetailLine('Headline: Dispatch opened for SITE-SANDTON'),
      findsOneWidget,
    );
    expect(
      richDetailLine(
        'Detail: Response team activated and client updates started.',
      ),
      findsOneWidget,
    );
    expect(richDetailLine('Events: 1 event'), findsOneWidget);
    expect(find.text('Thread Milestones'), findsOneWidget);
    expect(find.text('Opened'), findsWidgets);
    expect(find.text('DISP-001'), findsWidgets);
    expect(find.text('Dispatch opened for SITE-SANDTON'), findsWidgets);
    expect(
      find.text('Response team activated and client updates started.'),
      findsWidgets,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.campaign_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.flash_on_rounded), findsNWidgets(2));
    expect(find.text('Residents'), findsOneWidget);
    expect(find.text('Room Focus: Residents'), findsOneWidget);
    expect(find.text('Showing pending: Residents'), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);
    expect(find.text('ONYX • 10:20 UTC'), findsOneWidget);
    expect(find.text('Unread Alerts'), findsOneWidget);
    expect(find.text('Direct Chat'), findsOneWidget);
    expect(find.text('Client Acks Pending'), findsOneWidget);
    expect(find.text('Target: Client Ack • 10:20 UTC'), findsOneWidget);
    expect(find.text('Target: Resident Seen • 10:15 UTC'), findsOneWidget);
    expect(find.text('Queued'), findsWidgets);
    expect(find.text('Target: Residents'), findsWidgets);
    expect(find.text('Confirm receipt for Residents'), findsOneWidget);
    expect(find.text('Please share ETA for Residents'), findsOneWidget);
    expect(find.text('Client informed in Residents'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Request ETA for Residents'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Review Advisory for Residents'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Send Advisory to Residents'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Dispatch responses for Residents require client review before sending.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Open Client Review for Residents'),
      findsOneWidget,
    );
    expect(find.text('Send secure client update...'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send'), findsOneWidget);
    final openClientReviewButton = find.widgetWithText(
      TextButton,
      'Open Client Review for Residents',
    );
    await tester.ensureVisible(openClientReviewButton);
    await tester.tap(openClientReviewButton);
    await tester.pump();
    expect(
      find.text('Client review draft opened for Residents'),
      findsOneWidget,
    );
    final clientComposer = tester.widget<TextField>(find.byType(TextField));
    expect(
      clientComposer.controller?.text,
      'Please share the latest ETA for dispatch created in Residents.',
    );
    expect(clientComposer.decoration?.fillColor, const Color(0xFF13284A));
    expect(
      (clientComposer.decoration?.enabledBorder as OutlineInputBorder)
          .borderSide
          .color,
      const Color(0xFF8FD1FF),
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
      'Client reviewed the advisory and is ready to share it with Residents.',
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
    expect(find.text('Jumped to latest reply'), findsOneWidget);
    expect(
      find.text(
        'Client reviewed the advisory and is ready to share it with Residents.',
      ),
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 25),
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

    expect(find.text('Room Focus: Trustees'), findsOneWidget);
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 20),
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

    expect(find.text('Client Ack'), findsNWidgets(2));
    expect(find.text('Target: Client Ack • 10:20 UTC'), findsOneWidget);
    expect(find.text('Queued'), findsWidgets);
    expect(find.text('Control Ack'), findsNothing);
    expect(find.text('Resident Seen'), findsNothing);
    await tester.ensureVisible(find.text('Client Ack').first);
    await tester.tap(find.text('Client Ack').first);
    await tester.pump();

    expect(acknowledgements, hasLength(1));
    expect(
      acknowledgements.first.channel,
      ClientAppAcknowledgementChannel.client,
    );
    expect(acknowledgements.first.acknowledgedBy, 'Client');
    expect(find.text('Client Ack'), findsNothing);
    expect(find.textContaining('Client Ack by Client at'), findsNWidgets(2));
    expect(find.text('Delivered'), findsOneWidget);
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 15),
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 20),
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

    expect(find.text('Client Ack'), findsNothing);
    expect(find.text('Control Ack'), findsNWidgets(4));
    expect(find.text('Resident Seen'), findsNothing);
    expect(find.text('Open Alerts'), findsOneWidget);
    expect(find.text('Active Incident Timeline'), findsOneWidget);
    expect(find.text('Desk Thread'), findsOneWidget);
    expect(find.text('Control Acks Pending'), findsOneWidget);
    expect(find.text('Control Alerts'), findsOneWidget);
    expect(
      find.text(
        'Operational alarms, dispatch state changes, and response-critical updates. Showing pending notifications for Resident Feed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Audience Channels'), findsOneWidget);
    expect(
      find.text(
        'View pending acknowledgement lanes across residents, trustees, and desk response. Current lane: Resident Feed • lane-pending activity in focus.',
      ),
      findsOneWidget,
    );
    expect(find.text('Desk Coordination Thread'), findsOneWidget);
    expect(
      find.text(
        'Control-side coordination with mirrored ONYX updates and acknowledgements. Showing pending thread messages for Resident Feed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Resident Feed'), findsOneWidget);
    expect(find.text('Trustee Board'), findsOneWidget);
    expect(find.text('Desk Ops'), findsOneWidget);
    expect(find.text('Room Focus: Resident Feed'), findsOneWidget);
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
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Send Now'), findsNothing);
    expect(
      find.text(
        'Dispatch responses for Resident Feed must be reviewed before sending.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Open Dispatch Draft for Resident Feed'),
      findsOneWidget,
    );
    expect(find.text('Log a resident-lane control update...'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Log Resident Update'),
      findsOneWidget,
    );
    expect(find.text('Ready: Update'), findsOneWidget);

    final openDispatchDraftButton = find.widgetWithText(
      TextButton,
      'Open Dispatch Draft for Resident Feed',
    );
    await tester.ensureVisible(openDispatchDraftButton);
    await tester.tap(openDispatchDraftButton);
    await tester.pump();
    expect(
      find.text('Dispatch draft opened for Resident Feed'),
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
      'Control reviewing dispatch response for Resident Feed.',
    );
    expect(controlComposer.decoration?.fillColor, const Color(0xFF13284A));
    await tester.pump(const Duration(milliseconds: 950));
    final deskOpsRoomTile = find.ancestor(
      of: find.text('Desk Ops').first,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(deskOpsRoomTile.first).onTap!.call();
    await tester.pump();

    expect(find.text('Room Focus: Desk Ops'), findsOneWidget);
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
    expect(find.text('Jumped to latest log entry'), findsOneWidget);
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
                'Control drafting the advisory log entry for Desk Ops.',
      ),
      isTrue,
    );
    expect(find.text('Control team notified for Desk Ops'), findsWidgets);

    tester
        .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Resident View'),
        )
        .onPressed!
        .call();
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
    expect(find.text('Room Focus: Community'), findsOneWidget);
    expect(find.text('Showing pending: Community'), findsOneWidget);
    expect(find.text('Safety Thread DISP-001 • 1 update'), findsOneWidget);
    expect(find.text('Collapse Safety'), findsOneWidget);
    expect(find.text('Security responding at SITE-SANDTON'), findsNWidgets(2));
    expect(find.text('Updated 10:20 UTC'), findsOneWidget);
    expect(
      find.text('Security has been notified and updates are in progress.'),
      findsOneWidget,
    );
    expect(find.text('Control Ack'), findsNothing);
    expect(find.text('Resident Seen'), findsWidgets);
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 15),
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
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Post Advisory to Community'),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Draft Community Alert for Community',
      ),
    );
    await tester.pump();
    final residentComposer = tester.widget<TextField>(find.byType(TextField));
    expect(
      residentComposer.controller?.text,
      'Resident is drafting a community alert for Community now.',
    );
    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'Post Advisory to Community'),
        )
        .onPressed!
        .call();
    await tester.pump();
    expect(find.text('Community alert posted to Community'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'View Resident Reply'),
      findsOneWidget,
    );
    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'View Resident Reply'),
        )
        .onPressed!
        .call();
    await tester.pump();
    expect(find.text('Jumped to latest resident reply'), findsOneWidget);
    expect(
      find.text('Resident is drafting a community alert for Community now.'),
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
    expect(find.text('No control alerts in the current lane.'), findsOneWidget);
    expect(
      find.text('No desk coordination messages in this lane.'),
      findsOneWidget,
    );
    final noThreadButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'No Thread Selected'),
    );
    expect(noThreadButton.onPressed, isNull);
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 20),
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Room Focus: Security Desk'), findsOneWidget);
    expect(
      find.text('Showing all notifications • current lane: Security Desk'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Residents, trustees, and control channels. Current lane: Security Desk • all message activity visible.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Alarm triggers, arrivals, closures, and intelligence advisories. Showing all notifications • current lane: Security Desk',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Secure client thread with operational updates. Showing all thread messages • current lane: Security Desk',
      ),
      findsOneWidget,
    );
    expect(find.text('Target (current lane): Security Desk'), findsWidgets);
    expect(find.text('Show pending'), findsOneWidget);
    expect(find.text('Dispatch created'), findsWidgets);
  });

  testWidgets('room selection filters to pending items for that audience', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final occurredAt = DateTime.utc(2026, 3, 4, 10, 20);
    final messageKey =
        'system:${occurredAt.millisecondsSinceEpoch}:'
        'Dispatch created:'
        'Response team activated for SITE-SANDTON.';

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
              acknowledgedAt: DateTime.utc(2026, 3, 4, 10, 21),
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

    expect(find.text('Room Focus: Security Desk'), findsOneWidget);
    expect(find.text('Showing pending: Security Desk'), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);
    expect(find.text('No client notifications yet.'), findsOneWidget);
    expect(find.text('No direct chat messages yet.'), findsOneWidget);

    await tester.tap(find.text('Show all'));
    await tester.pump();

    expect(
      find.text('Showing all notifications • current lane: Security Desk'),
      findsOneWidget,
    );
    expect(find.text('Target (current lane): Security Desk'), findsWidgets);
    expect(find.text('Show pending'), findsOneWidget);
    expect(find.text('Dispatch created'), findsWidgets);
    expect(find.text('ONYX • 10:20 UTC'), findsOneWidget);

    await tester.tap(find.text('Residents').first);
    await tester.pump();

    expect(find.text('Room Focus: Residents'), findsOneWidget);
    expect(find.text('Showing pending: Residents'), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);
    expect(find.text('Dispatch created'), findsWidgets);
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 25),
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 20),
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

    await tester.tap(find.widgetWithText(TextButton, 'Open Incident'));
    await tester.pumpAndSettle();
    expect(find.text('Incident Detail'), findsOneWidget);
    expect(find.text('2 events'), findsWidgets);
    expect(find.text('Responder on site'), findsWidgets);
    expect(find.text('Dispatch opened for SITE-SANDTON'), findsWidgets);

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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 20),
              dispatchId: 'DISP-001',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Open Thread'));
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
    expect(find.widgetWithText(TextButton, 'No Thread Selected'), findsNothing);
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
      (decoration) => decoration.color == const Color(0xFF0D1B33),
    );
    expect(
      (controlIncidentDecoration.border! as Border).top.color,
      const Color(0xFF4A86C7),
    );
    expect(richDetailLine('Dispatch Thread: DISP-001'), findsOneWidget);
    expect(richDetailLine('Latest Milestone: Dispatched'), findsOneWidget);
    expect(richDetailLine('Logged: 10:20 UTC'), findsOneWidget);
    expect(
      richDetailLine('Operational Summary: Dispatch opened for SITE-SANDTON'),
      findsOneWidget,
    );
    expect(
      richDetailLine(
        'Operational Detail: Response team activated and client updates started.',
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 30),
              dispatchId: 'DISP-002',
              clientId: 'CLIENT-001',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-SANDTON',
            ),
            ResponseArrived(
              eventId: 'arrived-1',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 4, 10, 25),
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
              occurredAt: DateTime.utc(2026, 3, 4, 10, 20),
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
    expect(find.text('Tap to expand'), findsOneWidget);
    expect(find.text('Tap to collapse'), findsOneWidget);
    expect(find.text('Opened • 10:30 UTC'), findsNothing);
    expect(find.text('On Site • 10:25 UTC'), findsOneWidget);
    expect(find.text('Opened • 10:20 UTC'), findsOneWidget);
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
              occurredAt: DateTime.utc(2026, 3, 5, 10, 30),
              status: 'failed',
              failureReason: 'timeout',
              queueSize: 2,
            ),
            ClientPushSyncAttempt(
              occurredAt: DateTime.utc(2026, 3, 5, 10, 31),
              status: 'ok',
              queueSize: 0,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Push Sync History'), findsOneWidget);
    expect(
      find.textContaining('10:30 UTC • failed • queue:2 • timeout'),
      findsOneWidget,
    );
    expect(find.textContaining('10:31 UTC • ok • queue:0'), findsOneWidget);
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
          backendProbeLastRunAtUtc: DateTime.utc(2026, 3, 5, 11, 0),
          backendProbeHistory: [
            ClientBackendProbeAttempt(
              occurredAt: DateTime.utc(2026, 3, 5, 10, 59),
              status: 'failed',
              failureReason: 'network timeout',
            ),
            ClientBackendProbeAttempt(
              occurredAt: DateTime.utc(2026, 3, 5, 11, 0),
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
    expect(find.text('Backend Probe History'), findsOneWidget);
    expect(
      find.textContaining('10:59 UTC • failed • network timeout'),
      findsOneWidget,
    );
    expect(find.textContaining('11:00 UTC • ok'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Run Backend Probe'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Clear Probe History'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Run Backend Probe'));
    await tester.pump();
    expect(probeRuns, 1);
    await tester.tap(find.widgetWithText(TextButton, 'Clear Probe History'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Probe History?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(clearRuns, 1);
  });
}
