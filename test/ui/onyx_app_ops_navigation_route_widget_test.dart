import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/ai_queue_page.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';
import 'package:omnix_dashboard/ui/events_review_page.dart';
import 'package:omnix_dashboard/ui/onyx_agent_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

DateTime _opsNavigationOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 19, hour, minute);

Future<void> _openTacticalDetailedWorkspaceIfPresent(
  WidgetTester tester,
) async {
  final toggle = find.byKey(
    const ValueKey('tactical-toggle-detailed-workspace'),
  );
  if (toggle.evaluate().isEmpty) {
    return;
  }
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app opens scoped events from ai queue hero action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    List<String>? openedEventIds;
    String? openedSelectedEventId;
    String? openedScopeMode;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.aiQueue,
        initialStoreEventsOverride: [
          DecisionCreated(
            eventId: 'evt-ai-route-1',
            sequence: 1,
            version: 1,
            occurredAt: _opsNavigationOccurredAtUtc(7, 30),
            dispatchId: 'DSP-AI-1',
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ],
        onEventsScopeOpened: (eventIds, selectedEventId, scopeMode) {
          openedEventIds = eventIds;
          openedSelectedEventId = selectedEventId;
          openedScopeMode = scopeMode;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('ai-queue-toggle-detailed-workspace')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ai-queue-toggle-detailed-workspace')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai-queue-view-events-button')));
    await tester.pumpAndSettle();

    expect(openedEventIds, isNotNull);
    expect(openedEventIds, isNotEmpty);
    expect(openedSelectedEventId, isNotNull);
    expect(openedScopeMode, 'shadow');
    expect(find.byType(EventsReviewPage), findsOneWidget);
    expect(
      tester
          .widget<EventsReviewPage>(find.byType(EventsReviewPage))
          .initialScopedMode,
      'shadow',
    );
    expect(
      tester
          .widget<EventsReviewPage>(find.byType(EventsReviewPage))
          .initialScopedEventIds,
      openedEventIds,
    );
    expect(
      tester
          .widget<EventsReviewPage>(find.byType(EventsReviewPage))
          .initialSelectedEventId,
      openedSelectedEventId,
    );
  });

  testWidgets('onyx app opens agent from ai queue alert action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.aiQueue),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('ai-queue-action-open-agent')),
    );
    await tester.tap(find.byKey(const ValueKey('ai-queue-action-open-agent')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(find.text('Junior Analyst'), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'AI Queue',
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
      'INC-8829-QX',
    );
  });

  testWidgets('onyx app opens alarms from ai queue dispatch guard action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.aiQueue),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('ai-queue-action-dispatch-guard')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ai-queue-action-dispatch-guard')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DispatchPage), findsOneWidget);
    expect(
      tester.widget<DispatchPage>(find.byType(DispatchPage)).clientId,
      'CLIENT-DEMO',
    );
    expect(
      tester.widget<DispatchPage>(find.byType(DispatchPage)).siteId,
      'SITE-DEMO',
    );
    expect(
      tester
          .widget<DispatchPage>(find.byType(DispatchPage))
          .focusIncidentReference,
      'INC-8829-QX',
    );
  });

  testWidgets('onyx app returns from agent into the focused ai queue flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.aiQueue),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('ai-queue-action-open-agent')),
    );
    await tester.tap(find.byKey(const ValueKey('ai-queue-action-open-agent')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'AI Queue',
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
      'INC-8829-QX',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('onyx-agent-resume-ai-queue-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('onyx-agent-resume-ai-queue-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AIQueuePage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-queue-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('AGENT RETURN'), findsOneWidget);
    expect(find.textContaining('Returned from Agent for'), findsOneWidget);
    expect(
      tester
          .widget<AIQueuePage>(find.byType(AIQueuePage))
          .focusIncidentReference,
      'INC-8829-QX',
    );
  });

  testWidgets('onyx app opens events from governance hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.governance),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('governance-view-events-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EventsReviewPage), findsOneWidget);
    expect(
      tester
          .widget<EventsReviewPage>(find.byType(EventsReviewPage))
          .initialScopedMode,
      'shadow',
    );
    expect(
      tester
          .widget<EventsReviewPage>(find.byType(EventsReviewPage))
          .initialScopedEventIds,
      isNotEmpty,
    );
    expect(
      tester
          .widget<EventsReviewPage>(find.byType(EventsReviewPage))
          .initialSelectedEventId,
      isNotEmpty,
    );
  });

  testWidgets('onyx app opens ledger from governance quick actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.governance),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('governance-quick-view-ledger-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('governance-quick-view-ledger-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SovereignLedgerPage), findsOneWidget);
    expect(
      tester
          .widget<SovereignLedgerPage>(find.byType(SovereignLedgerPage))
          .initialScopeClientId,
      'CLIENT-DEMO',
    );
    expect(
      tester
          .widget<SovereignLedgerPage>(find.byType(SovereignLedgerPage))
          .initialScopeSiteId,
      'SITE-DEMO',
    );
  });

  testWidgets('onyx app opens dispatches from tactical hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.tactical),
    );
    await tester.pumpAndSettle();
    await _openTacticalDetailedWorkspaceIfPresent(tester);

    await tester.tap(
      find.byKey(const ValueKey('tactical-open-dispatches-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DispatchPage), findsOneWidget);
    expect(
      tester.widget<DispatchPage>(find.byType(DispatchPage)).clientId,
      'CLIENT-DEMO',
    );
    expect(
      tester.widget<DispatchPage>(find.byType(DispatchPage)).siteId,
      'SITE-DEMO',
    );
  });

  testWidgets('onyx app shows the shell status summary snack', (tester) async {
    tester.view.physicalSize = const Size(2100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.governance),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-shell-status-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ready.'), findsOneWidget);
  });

  testWidgets('onyx app quick jump navigates to dispatches', (tester) async {
    tester.view.physicalSize = const Size(2100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.governance),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('app-shell-quick-jump-input')),
      'dispatch',
    );
    await tester.pump();

    await tester.tap(find.text('Dispatches').last);
    await tester.pumpAndSettle();

    expect(find.byType(DispatchPage), findsOneWidget);
  });
}
