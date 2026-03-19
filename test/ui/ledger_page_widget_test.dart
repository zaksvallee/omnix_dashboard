import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/ui/ledger_page.dart';

import '../fixtures/report_test_receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ledger page stays stable on phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: LedgerPage(
          clientId: 'CLIENT-001',
          supabaseEnabled: false,
          events: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sovereign Ledger'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ledger page stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: LedgerPage(
          clientId: 'CLIENT-001',
          supabaseEnabled: false,
          events: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sovereign Ledger'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ledger page shows fallback runtime hint when Supabase is disabled',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LedgerPage(
            clientId: 'CLIENT-001',
            supabaseEnabled: false,
            events: [],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EventStore'), findsWidgets);
      expect(
        find.textContaining(
          'Run with local defines: ./scripts/run_onyx_chrome_local.sh',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('ledger page events action opens helper dialog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LedgerPage(
          clientId: 'CLIENT-001',
          supabaseEnabled: false,
          events: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ledger-view-events-button')));
    await tester.pumpAndSettle();

    expect(find.text('Events Link Ready'), findsOneWidget);
    expect(
      find.textContaining('forensic timeline, selected event payloads'),
      findsOneWidget,
    );
  });

  testWidgets(
    'ledger page shows tracked report section configuration in fallback timeline',
    (tester) async {
      final events = <DispatchEvent>[
        buildTestReportGenerated(
          eventId: 'RPT-LEDGER-PAGE-1',
          sequence: 1,
          occurredAt: DateTime.utc(2026, 3, 15, 6, 0),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          month: '2026-03',
          reportSchemaVersion: 3,
          primaryBrandLabel: 'VISION Tactical',
          endorsementLine: 'Powered by ONYX',
          brandingSourceLabel: 'PARTNER • Alpha',
          brandingUsesOverride: true,
          investigationContextKey: 'governance_branding_drift',
          includeAiDecisionLog: false,
          includeGuardMetrics: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: LedgerPage(
            clientId: 'CLIENT-001',
            supabaseEnabled: false,
            events: events,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REPORT GENERATED'), findsOneWidget);
      expect(
        find.textContaining(
          '2 sections omitted • custom branding override • governance handoff',
        ),
        findsOneWidget,
      );
      expect(find.text('Custom Branding'), findsOneWidget);
      expect(
        find.text(
          'Branding: custom override from default partner lane PARTNER • Alpha. Included: Incident Timeline, Dispatch Summary, Checkpoint Compliance. Omitted: AI Decision Log, Guard Metrics. Investigation: this receipt was generated from a Governance branding-drift handoff.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ledger page labels legacy report receipt configuration in fallback timeline',
    (tester) async {
      final events = <DispatchEvent>[
        buildTestReportGenerated(
          eventId: 'RPT-LEDGER-PAGE-LEGACY-1',
          sequence: 1,
          occurredAt: DateTime.utc(2026, 3, 15, 6, 0),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          month: '2026-03',
          reportSchemaVersion: 1,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: LedgerPage(
            clientId: 'CLIENT-001',
            supabaseEnabled: false,
            events: events,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REPORT GENERATED'), findsOneWidget);
      expect(find.textContaining('legacy receipt config'), findsOneWidget);
      expect(find.text('Legacy Config'), findsOneWidget);
      expect(
        find.text(
          'Branding: standard ONYX identity. Legacy receipt. Per-section report configuration was not captured for this generated report. Investigation: routine report review.',
        ),
        findsOneWidget,
      );
    },
  );
}
