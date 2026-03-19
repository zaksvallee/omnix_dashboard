import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';
import 'package:omnix_dashboard/ui/events_review_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app opens scoped events from ai queue hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
            occurredAt: DateTime.utc(2026, 3, 19, 7, 30),
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

    await tester.tap(find.byKey(const ValueKey('ai-queue-view-events-button')));
    await tester.pumpAndSettle();

    expect(openedEventIds, isNotNull);
    expect(openedEventIds, isNotEmpty);
    expect(openedSelectedEventId, isNotNull);
    expect(openedScopeMode, 'shadow');
    expect(find.byType(EventsReviewPage), findsOneWidget);
  });

  testWidgets('onyx app opens events from governance hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.governance,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('governance-view-events-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EventsReviewPage), findsOneWidget);
  });

  testWidgets('onyx app opens ledger from governance quick actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.governance,
      ),
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
  });

  testWidgets('onyx app opens dispatches from tactical hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.tactical,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('tactical-open-dispatches-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DispatchPage), findsOneWidget);
  });

  testWidgets('onyx app shows the shell status summary snack', (tester) async {
    tester.view.physicalSize = const Size(2100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.governance,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-shell-status-button')));
    await tester.pump();

    expect(find.textContaining('Systems nominal.'), findsOneWidget);
  });

  testWidgets('onyx app quick jump navigates to dispatches', (tester) async {
    tester.view.physicalSize = const Size(2100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.governance,
      ),
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
