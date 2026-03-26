import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/events_review_page.dart';
import 'package:omnix_dashboard/ui/governance_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';
import 'package:omnix_dashboard/presentation/reports/report_preview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app opens governance from routed reports hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.reports),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reports & Documentation'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('reports-routed-view-governance-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GovernancePage), findsOneWidget);
  });

  testWidgets('onyx app generates a routed report from the hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.reports),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reports & Documentation'), findsOneWidget);
    expect(find.textContaining('Preview target:'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('reports-routed-generate-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ReportPreviewPage), findsOneWidget);
  });

  testWidgets(
    'onyx app opens sovereign ledger from routed events hero action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.events),
      );
      await tester.pumpAndSettle();

      expect(find.text('Events & Forensic Timeline'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('events-routed-view-ledger-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SovereignLedgerPage), findsOneWidget);
    },
  );

  testWidgets('onyx app opens governance from routed events hero action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.events),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events & Forensic Timeline'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('events-routed-view-governance-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GovernancePage), findsOneWidget);
  });

  testWidgets('onyx app opens scoped events from routed ledger hero action', (
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
        initialRouteOverride: OnyxRoute.ledger,
        onEventsScopeOpened: (eventIds, selectedEventId, scopeMode) {
          openedEventIds = eventIds;
          openedSelectedEventId = selectedEventId;
          openedScopeMode = scopeMode;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Occurrence Book'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('ledger-hero-view-events-button')),
    );
    await tester.pumpAndSettle();

    expect(openedEventIds, isNotNull);
    expect(openedEventIds, isNotEmpty);
    expect(openedSelectedEventId, isNotNull);
    expect(openedScopeMode, isEmpty);
    expect(find.byType(EventsReviewPage), findsOneWidget);
  });

  testWidgets(
    'onyx app verifies the routed ledger chain from the hero action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.ledger),
      );
      await tester.pumpAndSettle();

      expect(find.text('Occurrence Book'), findsOneWidget);
      expect(find.text('INTACT'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ledger-hero-verify-button')));
      await tester.pumpAndSettle();

      expect(find.text('INTACT'), findsWidgets);
    },
  );
}
