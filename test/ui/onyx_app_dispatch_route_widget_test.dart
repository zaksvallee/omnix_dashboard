import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/ai_queue_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/clients_page.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';
import 'package:omnix_dashboard/ui/onyx_agent_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';
import 'package:omnix_dashboard/ui/tactical_page.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';

import 'support/watch_drilldown_route_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openDetailedWorkspaceIfVisible(WidgetTester tester) async {
    final toggle = find.byKey(
      const ValueKey('dispatch-toggle-detailed-workspace'),
    );
    if (toggle.evaluate().isEmpty) {
      return;
    }
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  testWidgets('onyx app reopens dispatch warm from signed dispatch evidence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.ledger,
        initialPinnedLedgerAuditEntryOverride: SovereignLedgerPinnedAuditEntry(
          auditId: 'DSP-AUDIT-LAUNCH-1',
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          recordCode: 'OB-AUDIT',
          title: 'Dispatch launched for DSP-2442.',
          description:
              'Opened the live dispatch board for DSP-2442 from Dispatch.',
          occurredAt: DateTime.utc(2026, 3, 27, 22, 50),
          actorLabel: 'Control-1',
          sourceLabel: 'Dispatch War Room',
          hash: 'dispatchlaunchhash1',
          previousHash: 'dispatchlaunchprev1',
          accent: const Color(0xFFF59E0B),
          payload: const <String, Object?>{
            'type': 'dispatch_auto_audit',
            'action': 'dispatch_launched',
            'dispatch_id': 'DSP-2442',
            'incident_reference': 'INC-DSP-2442',
            'source_route': 'dispatches',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sovereign Ledger'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-dispatch')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-entry-open-dispatch')));
    await tester.pumpAndSettle();

    expect(find.byType(DispatchPage), findsOneWidget);
    await openDetailedWorkspaceIfVisible(tester);

    expect(
      find.byKey(const ValueKey('dispatch-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('EVIDENCE RETURN'), findsOneWidget);
    expect(
      find.text('Returned to live dispatch for DSP-2442.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'onyx app restores limited watch drilldown into dispatch after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveDispatchWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.limited,
      );
      await seedValleeLimitedWatchRuntime(persistence: persistence);

      await pumpValleeWatchDrilldownRouteApp(
        tester,
        route: OnyxRoute.dispatches,
      );

      await openDetailedWorkspaceIfVisible(tester);

      await tester.scrollUntilVisible(
        find.text('Focused watch action: Limited watch coverage'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsOneWidget,
      );
    },
  );

  testWidgets('onyx app opens track from dispatch alarm action row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.dispatches),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    final trackOfficerButton = find
        .byKey(const ValueKey('dispatch-action-track-officer'))
        .hitTestable();
    await tester.ensureVisible(trackOfficerButton);
    await tester.tap(trackOfficerButton);
    await tester.pumpAndSettle();

    expect(find.byType(TacticalPage), findsOneWidget);
    expect(
      tester
          .widget<TacticalPage>(find.byType(TacticalPage))
          .initialScopeClientId,
      'CLIENT-DEMO',
    );
    expect(
      tester.widget<TacticalPage>(find.byType(TacticalPage)).initialScopeSiteId,
      'SITE-DEMO',
    );
  });

  testWidgets('onyx app opens track from focus-backed dispatch route seed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        initialDispatchIncidentReferenceOverride: 'DSP-4',
      ),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    expect(
      tester
          .widget<DispatchPage>(find.byType(DispatchPage))
          .initialSelectedDispatchId,
      'DSP-4',
    );

    final trackOfficerButton = find
        .byKey(const ValueKey('dispatch-action-track-officer'))
        .hitTestable();
    await tester.ensureVisible(trackOfficerButton);
    await tester.tap(trackOfficerButton);
    await tester.pumpAndSettle();

    expect(find.byType(TacticalPage), findsOneWidget);
    expect(
      tester
          .widget<TacticalPage>(find.byType(TacticalPage))
          .initialScopeClientId,
      'CLIENT-DEMO',
    );
    expect(
      tester.widget<TacticalPage>(find.byType(TacticalPage)).initialScopeSiteId,
      'SITE-DEMO',
    );
    expect(
      tester
          .widget<TacticalPage>(find.byType(TacticalPage))
          .focusIncidentReference,
      'DSP-4',
    );
  });

  testWidgets('onyx app opens cctv from dispatch alarm action row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.dispatches),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    final viewCameraButton = find
        .byKey(const ValueKey('dispatch-action-view-camera'))
        .hitTestable();
    await tester.ensureVisible(viewCameraButton);
    await tester.tap(viewCameraButton);
    await tester.pumpAndSettle();

    expect(find.byType(AIQueuePage), findsOneWidget);
  });

  testWidgets('onyx app opens cctv from focus-backed dispatch route seed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        initialDispatchIncidentReferenceOverride: 'DSP-4',
      ),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    expect(
      tester
          .widget<DispatchPage>(find.byType(DispatchPage))
          .initialSelectedDispatchId,
      'DSP-4',
    );

    final viewCameraButton = find
        .byKey(const ValueKey('dispatch-action-view-camera'))
        .hitTestable();
    await tester.ensureVisible(viewCameraButton);
    await tester.tap(viewCameraButton);
    await tester.pumpAndSettle();

    expect(find.byType(AIQueuePage), findsOneWidget);
    expect(
      tester
          .widget<AIQueuePage>(find.byType(AIQueuePage))
          .focusIncidentReference,
      'DSP-4',
    );
  });

  testWidgets('onyx app opens comms from dispatch alarm action row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.dispatches),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    final callClientButton = find
        .byKey(const ValueKey('dispatch-action-call-client'))
        .hitTestable();
    await tester.ensureVisible(callClientButton);
    await tester.tap(callClientButton);
    await tester.pumpAndSettle();

    expect(find.byType(ClientsPage), findsOneWidget);
  });

  testWidgets('onyx app opens comms from focus-backed dispatch route seed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        initialDispatchIncidentReferenceOverride: 'DSP-4',
      ),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    expect(
      tester
          .widget<DispatchPage>(find.byType(DispatchPage))
          .initialSelectedDispatchId,
      'DSP-4',
    );

    final callClientButton = find
        .byKey(const ValueKey('dispatch-action-call-client'))
        .hitTestable();
    await tester.ensureVisible(callClientButton);
    await tester.tap(callClientButton);
    await tester.pumpAndSettle();

    expect(find.byType(ClientsPage), findsOneWidget);
    expect(
      tester.widget<ClientsPage>(find.byType(ClientsPage)).clientId,
      'CLIENT-DEMO',
    );
    expect(
      tester.widget<ClientsPage>(find.byType(ClientsPage)).siteId,
      'SITE-DEMO',
    );
  });

  testWidgets('onyx app opens comms from cleared dispatch action row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.dispatches),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    final openCommsButton = find
        .widgetWithText(OutlinedButton, 'OPEN CLIENT COMMS')
        .hitTestable()
        .first;
    await tester.ensureVisible(openCommsButton);
    await tester.tap(openCommsButton);
    await tester.pumpAndSettle();

    expect(find.byType(ClientsPage), findsOneWidget);
    expect(find.textContaining('Client Communications'), findsWidgets);
  });

  testWidgets('onyx app opens agent from dispatch alarm action row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.dispatches),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);
    final initialDispatchPage = tester.widget<DispatchPage>(
      find.byType(DispatchPage),
    );
    final expectedDispatchId =
        initialDispatchPage.initialSelectedDispatchId?.trim().isNotEmpty == true
        ? initialDispatchPage.initialSelectedDispatchId!.trim()
        : initialDispatchPage.focusIncidentReference.trim().replaceFirst(
            'INC-',
            '',
          );

    final askAgentButton = find
        .byKey(const ValueKey('dispatch-action-open-agent'))
        .hitTestable();
    await tester.ensureVisible(askAgentButton);
    await tester.tap(askAgentButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(find.text('Junior Analyst'), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'Dispatches',
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
      expectedDispatchId,
    );
  });

  testWidgets('onyx app opens agent from focus-backed dispatch route seed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        initialDispatchIncidentReferenceOverride: 'DSP-4',
      ),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);

    expect(
      tester
          .widget<DispatchPage>(find.byType(DispatchPage))
          .initialSelectedDispatchId,
      'DSP-4',
    );

    final askAgentButton = find
        .byKey(const ValueKey('dispatch-action-open-agent'))
        .hitTestable();
    await tester.ensureVisible(askAgentButton);
    await tester.tap(askAgentButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(find.text('Junior Analyst'), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'Dispatches',
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
      'DSP-4',
    );
  });

  testWidgets('onyx app resumes dispatch directly from the agent header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.dispatches),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);
    final initialDispatchPage = tester.widget<DispatchPage>(
      find.byType(DispatchPage),
    );
    final expectedDispatchId =
        initialDispatchPage.initialSelectedDispatchId?.trim().isNotEmpty == true
        ? initialDispatchPage.initialSelectedDispatchId!.trim()
        : initialDispatchPage.focusIncidentReference.trim().replaceFirst(
            'INC-',
            '',
          );

    final askAgentButton = find
        .byKey(const ValueKey('dispatch-action-open-agent'))
        .hitTestable();
    await tester.ensureVisible(askAgentButton);
    await tester.tap(askAgentButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'Dispatches',
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
      expectedDispatchId,
    );

    final resumeAlarmsButton = find.byKey(
      const ValueKey('onyx-agent-resume-alarms-button'),
    );
    await tester.ensureVisible(resumeAlarmsButton);
    await tester.tap(resumeAlarmsButton);
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    expect(find.byType(DispatchPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dispatch-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('AGENT RETURN'), findsOneWidget);
  });

  testWidgets(
    'onyx app resumes focus-backed dispatch route directly from the agent header',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dispatches,
          initialDispatchIncidentReferenceOverride: 'DSP-4',
        ),
      );
      await tester.pumpAndSettle();
      await openDetailedWorkspaceIfVisible(tester);

      expect(
        tester
            .widget<DispatchPage>(find.byType(DispatchPage))
            .initialSelectedDispatchId,
        'DSP-4',
      );

      final askAgentButton = find
          .byKey(const ValueKey('dispatch-action-open-agent'))
          .hitTestable();
      await tester.ensureVisible(askAgentButton);
      await tester.tap(askAgentButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(OnyxAgentPage), findsOneWidget);
      expect(
        tester
            .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
            .sourceRouteLabel,
        'Dispatches',
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
        'DSP-4',
      );

      final resumeAlarmsButton = find.byKey(
        const ValueKey('onyx-agent-resume-alarms-button'),
      );
      await tester.ensureVisible(resumeAlarmsButton);
      await tester.tap(resumeAlarmsButton);
      await tester.pumpAndSettle();

      await openDetailedWorkspaceIfVisible(tester);

      expect(find.byType(DispatchPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dispatch-workspace-command-receipt')),
        findsOneWidget,
      );
      expect(find.text('AGENT RETURN'), findsOneWidget);
      expect(
        tester
            .widget<DispatchPage>(find.byType(DispatchPage))
            .initialSelectedDispatchId,
        'DSP-4',
      );
    },
  );

  testWidgets('onyx app returns from agent into the focused dispatch board', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.dispatches),
    );
    await tester.pumpAndSettle();
    await openDetailedWorkspaceIfVisible(tester);
    final initialDispatchPage = tester.widget<DispatchPage>(
      find.byType(DispatchPage),
    );
    final expectedDispatchId =
        initialDispatchPage.initialSelectedDispatchId?.trim().isNotEmpty == true
        ? initialDispatchPage.initialSelectedDispatchId!.trim()
        : initialDispatchPage.focusIncidentReference.trim().replaceFirst(
            'INC-',
            '',
          );

    final askAgentButton = find
        .byKey(const ValueKey('dispatch-action-open-agent'))
        .hitTestable();
    await tester.ensureVisible(askAgentButton);
    await tester.tap(askAgentButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'Dispatches',
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
      expectedDispatchId,
    );

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Dispatch alarm handoff and keep the current incident pinned',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final messageListScrollable = find.descendant(
      of: find.byKey(const ValueKey('onyx-agent-message-list')),
      matching: find.byType(Scrollable),
    );
    final reopenAlarmsAction = find.byKey(
      const ValueKey('onyx-agent-action-dispatch-open-alarms'),
    );
    await tester.scrollUntilVisible(
      reopenAlarmsAction,
      220,
      scrollable: messageListScrollable,
    );
    final reopenAlarmsButton = tester.widget<OutlinedButton>(
      reopenAlarmsAction,
    );
    expect(reopenAlarmsButton.onPressed, isNotNull);
    reopenAlarmsButton.onPressed!.call();
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    expect(find.byType(DispatchPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dispatch-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('AGENT RETURN'), findsOneWidget);
    expect(find.textContaining('Returned from Agent'), findsOneWidget);
    expect(
      tester
          .widget<DispatchPage>(find.byType(DispatchPage))
          .initialSelectedDispatchId,
      expectedDispatchId,
    );
  });

  testWidgets(
    'onyx app returns from agent into the focus-backed dispatch route seed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dispatches,
          initialDispatchIncidentReferenceOverride: 'DSP-4',
        ),
      );
      await tester.pumpAndSettle();
      await openDetailedWorkspaceIfVisible(tester);

      expect(
        tester
            .widget<DispatchPage>(find.byType(DispatchPage))
            .initialSelectedDispatchId,
        'DSP-4',
      );

      final askAgentButton = find
          .byKey(const ValueKey('dispatch-action-open-agent'))
          .hitTestable();
      await tester.ensureVisible(askAgentButton);
      await tester.tap(askAgentButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(OnyxAgentPage), findsOneWidget);
      expect(
        tester
            .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
            .sourceRouteLabel,
        'Dispatches',
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
        'DSP-4',
      );

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Dispatch route seed handoff and keep DSP-4 pinned in alarms',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final messageListScrollable = find.descendant(
        of: find.byKey(const ValueKey('onyx-agent-message-list')),
        matching: find.byType(Scrollable),
      );
      final reopenAlarmsAction = find.byKey(
        const ValueKey('onyx-agent-action-dispatch-open-alarms'),
      );
      await tester.scrollUntilVisible(
        reopenAlarmsAction,
        220,
        scrollable: messageListScrollable,
      );
      final reopenAlarmsButton = tester.widget<OutlinedButton>(
        reopenAlarmsAction,
      );
      expect(reopenAlarmsButton.onPressed, isNotNull);
      reopenAlarmsButton.onPressed!.call();
      await tester.pumpAndSettle();

      await openDetailedWorkspaceIfVisible(tester);

      expect(find.byType(DispatchPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dispatch-workspace-command-receipt')),
        findsOneWidget,
      );
      expect(find.text('AGENT RETURN'), findsOneWidget);
      expect(find.textContaining('Returned from Agent'), findsOneWidget);
      expect(
        tester
            .widget<DispatchPage>(find.byType(DispatchPage))
            .initialSelectedDispatchId,
        'DSP-4',
      );
    },
  );

  testWidgets('onyx app keeps dispatch watch drilldown cleared after restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final persistence = await DispatchPersistenceService.create();
    await persistence.saveDispatchWatchActionDrilldown(
      VideoFleetWatchActionDrilldown.limited,
    );
    await seedValleeLimitedWatchRuntime(persistence: persistence);

    await pumpValleeWatchDrilldownRouteApp(
      tester,
      route: OnyxRoute.dispatches,
      key: const ValueKey('dispatch-clear-limited-source-app'),
    );

    await openDetailedWorkspaceIfVisible(tester);

    await tester.scrollUntilVisible(
      find.text('Focused watch action: Limited watch coverage'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsNothing,
    );

    await pumpValleeWatchDrilldownRouteApp(
      tester,
      route: OnyxRoute.dispatches,
      key: const ValueKey('dispatch-clear-limited-restart-app'),
    );

    expect(
      find.text('Focused watch action: Limited watch coverage'),
      findsNothing,
    );
  });

  testWidgets(
    'onyx app persists dispatch watch drilldown replacement after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final persistence = await DispatchPersistenceService.create();
      await persistence.saveDispatchWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.alerts,
      );
      await seedValleeLimitedWatchRuntime(
        persistence: persistence,
        alertCount: 1,
      );

      await pumpValleeWatchDrilldownRouteApp(
        tester,
        route: OnyxRoute.dispatches,
        key: const ValueKey('dispatch-replace-watch-action-source-app'),
      );

      await openDetailedWorkspaceIfVisible(tester);

      await tester.scrollUntilVisible(
        find.text('Focused watch action: Alert actions'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Focused watch action: Alert actions'), findsOneWidget);

      await persistence.saveDispatchWatchActionDrilldown(
        VideoFleetWatchActionDrilldown.limited,
      );

      await pumpValleeWatchDrilldownRouteApp(
        tester,
        route: OnyxRoute.dispatches,
        key: const ValueKey('dispatch-replace-watch-action-restart-app'),
      );

      await openDetailedWorkspaceIfVisible(tester);

      await tester.scrollUntilVisible(
        find.text('Focused watch action: Limited watch coverage'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Limited watch coverage'),
        findsOneWidget,
      );
      expect(find.text('Focused watch action: Alert actions'), findsNothing);
    },
  );

  testWidgets('onyx app opens scoped reports from cleared dispatch action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedDispatchId;
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        onDispatchReportRouteOpened: (dispatchId, clientId, siteId) {
          openedDispatchId = dispatchId;
          openedClientId = clientId;
          openedSiteId = siteId;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dispatch Board'), findsOneWidget);

    await openDetailedWorkspaceIfVisible(tester);

    final viewReportButton = find.byKey(
      const ValueKey('dispatch-selected-board-open-report'),
    );
    await tester.ensureVisible(viewReportButton);
    await tester.tap(viewReportButton);
    await tester.pumpAndSettle();

    expect(openedDispatchId, 'DSP-4');
    expect(openedClientId, 'CLIENT-DEMO');
    expect(openedSiteId, 'SITE-DEMO');
  });

  testWidgets(
    'onyx app opens scoped reports from focus-backed dispatch route seed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedDispatchId;
      String? openedClientId;
      String? openedSiteId;

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dispatches,
          initialDispatchIncidentReferenceOverride: 'DSP-4',
          onDispatchReportRouteOpened: (dispatchId, clientId, siteId) {
            openedDispatchId = dispatchId;
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      );
      await tester.pumpAndSettle();
      await openDetailedWorkspaceIfVisible(tester);

      expect(
        tester
            .widget<DispatchPage>(find.byType(DispatchPage))
            .initialSelectedDispatchId,
        'DSP-4',
      );

      final viewReportButton = find.byKey(
        const ValueKey('dispatch-selected-board-open-report'),
      );
      await tester.ensureVisible(viewReportButton);
      await tester.tap(viewReportButton);
      await tester.pumpAndSettle();

      expect(openedDispatchId, 'DSP-4');
      expect(openedClientId, 'CLIENT-DEMO');
      expect(openedSiteId, 'SITE-DEMO');
    },
  );

  testWidgets(
    'onyx app opens scoped reports from focus-backed dispatch hero route seed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? openedDispatchId;
      String? openedClientId;
      String? openedSiteId;

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dispatches,
          initialDispatchIncidentReferenceOverride: 'DSP-4',
          onDispatchReportRouteOpened: (dispatchId, clientId, siteId) {
            openedDispatchId = dispatchId;
            openedClientId = clientId;
            openedSiteId = siteId;
          },
        ),
      );
      await tester.pumpAndSettle();
      await openDetailedWorkspaceIfVisible(tester);

      expect(
        tester
            .widget<DispatchPage>(find.byType(DispatchPage))
            .initialSelectedDispatchId,
        'DSP-4',
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('dispatch-workspace-focus-open-report')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('dispatch-workspace-focus-open-report')),
      );
      await tester.pumpAndSettle();

      expect(openedDispatchId, 'DSP-4');
      expect(openedClientId, 'CLIENT-DEMO');
      expect(openedSiteId, 'SITE-DEMO');
    },
  );

  testWidgets('onyx app opens scoped reports from dispatch hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedDispatchId;
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        onDispatchReportRouteOpened: (dispatchId, clientId, siteId) {
          openedDispatchId = dispatchId;
          openedClientId = clientId;
          openedSiteId = siteId;
        },
      ),
    );
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('dispatch-workspace-focus-open-report')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('dispatch-workspace-focus-open-report')),
    );
    await tester.pumpAndSettle();

    expect(openedDispatchId, 'DSP-4');
    expect(openedClientId, 'CLIENT-DEMO');
    expect(openedSiteId, 'SITE-DEMO');
  });

  testWidgets('onyx app routes generate dispatch through shell callback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var generateTriggeredCount = 0;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        onDispatchGenerateTriggered: () {
          generateTriggeredCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await openDetailedWorkspaceIfVisible(tester);

    final generateButton = find.widgetWithText(
      FilledButton,
      'Generate Dispatch',
    );
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(generateTriggeredCount, 1);
  });

  testWidgets(
    'onyx app surfaces auto-audit receipt after dispatch generation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(
          supabaseReady: false,
          initialRouteOverride: OnyxRoute.dispatches,
        ),
      );
      await tester.pumpAndSettle();
      await openDetailedWorkspaceIfVisible(tester);

      final generateButton = find.widgetWithText(
        FilledButton,
        'Generate Dispatch',
      );
      await tester.ensureVisible(generateButton);
      await tester.tap(generateButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dispatch-workspace-command-receipt')),
        findsOneWidget,
      );
      expect(find.text('AUTO-AUDIT'), findsOneWidget);
      expect(find.textContaining('signed automatically'), findsOneWidget);
    },
  );

  testWidgets('onyx app derives dispatch scope from incident route seed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedClientId;
    String? openedSiteId;
    String? openedFocusReference;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        initialDispatchIncidentReferenceOverride: 'DSP-4',
        onDispatchRouteOpened: (clientId, siteId, focusReference) {
          openedClientId = clientId;
          openedSiteId = siteId;
          openedFocusReference = focusReference;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dispatch Board'), findsOneWidget);
    await openDetailedWorkspaceIfVisible(tester);
    expect(openedClientId, 'CLIENT-DEMO');
    expect(openedSiteId, 'SITE-DEMO');
    expect(openedFocusReference, 'DSP-4');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dispatch-selected-board')),
        matching: find.text('DSP-4'),
      ),
      findsOneWidget,
    );
  });
}
