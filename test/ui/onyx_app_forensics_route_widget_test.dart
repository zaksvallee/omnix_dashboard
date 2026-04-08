import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/client_intelligence_reports_page.dart';
import 'package:omnix_dashboard/ui/events_review_page.dart';
import 'package:omnix_dashboard/ui/governance_page.dart';
import 'package:omnix_dashboard/ui/sovereign_ledger_page.dart';

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
    expect(
      tester
          .widget<GovernancePage>(find.byType(GovernancePage))
          .initialScopeClientId,
      'CLIENT-DEMO',
    );
    expect(
      tester
          .widget<GovernancePage>(find.byType(GovernancePage))
          .initialScopeSiteId,
      'SITE-DEMO',
    );
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

      expect(find.text('Events War Room'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('events-routed-view-ledger-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SovereignLedgerPage), findsOneWidget);
      expect(
        tester
            .widget<SovereignLedgerPage>(find.byType(SovereignLedgerPage))
            .clientId,
        'CLIENT-DEMO',
      );
      expect(
        tester
            .widget<SovereignLedgerPage>(find.byType(SovereignLedgerPage))
            .initialFocusReference,
        isNotEmpty,
      );
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

    expect(find.text('Events War Room'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('events-routed-view-governance-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GovernancePage), findsOneWidget);
    expect(
      tester
          .widget<GovernancePage>(find.byType(GovernancePage))
          .initialScopeClientId,
      isNull,
    );
    expect(
      tester
          .widget<GovernancePage>(find.byType(GovernancePage))
          .initialScopeSiteId,
      isNull,
    );
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

    expect(find.text('Sovereign Ledger'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('ledger-hero-view-events-button')),
    );
    await tester.pumpAndSettle();

    expect(openedEventIds, isNotNull);
    expect(openedEventIds, isNotEmpty);
    expect(openedSelectedEventId, isNotNull);
    expect(openedScopeMode, isEmpty);
    expect(find.byType(EventsReviewPage), findsOneWidget);
    expect(
      tester
          .widget<EventsReviewPage>(find.byType(EventsReviewPage))
          .initialScopedMode,
      isNull,
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

  testWidgets('onyx app opens reports warm from signed dispatch evidence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.ledger,
        initialPinnedLedgerAuditEntryOverride: SovereignLedgerPinnedAuditEntry(
          auditId: 'DSP-AUDIT-REPORT-1',
          clientId: 'CLIENT-DEMO',
          siteId: 'SITE-DEMO',
          recordCode: 'OB-AUDIT',
          title: 'Reports workspace opened for DSP-4.',
          description:
              'Opened the reports workspace for DSP-4 from the dispatch war room.',
          occurredAt: DateTime.utc(2026, 3, 27, 22, 56),
          actorLabel: 'Control-1',
          sourceLabel: 'Dispatch War Room',
          hash: 'dispatchreporthash1',
          previousHash: 'dispatchreportprev1',
          accent: const Color(0xFF8FD1FF),
          payload: const <String, Object?>{
            'type': 'dispatch_auto_audit',
            'action': 'report_handoff_opened',
            'dispatch_id': 'DSP-4',
            'incident_reference': 'INC-DSP-4',
            'source_route': 'dispatches',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sovereign Ledger'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-entry-open-dispatch-report')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ledger-entry-open-dispatch-report')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ClientIntelligenceReportsPage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('reports-workspace-command-receipt')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reports-workspace-command-receipt')),
      findsOneWidget,
    );
    expect(find.text('EVIDENCE RETURN'), findsOneWidget);
    expect(
      find.text('Returned to the reports workspace for DSP-4.'),
      findsOneWidget,
    );
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

      expect(find.text('Sovereign Ledger'), findsOneWidget);
      expect(find.text('INTACT'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ledger-hero-verify-button')));
      await tester.pumpAndSettle();

      expect(find.text('INTACT'), findsWidgets);
    },
  );
}
