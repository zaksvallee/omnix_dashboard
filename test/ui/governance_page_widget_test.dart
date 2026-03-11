import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/ui/governance_page.dart';

void main() {
  testWidgets('governance page stays stable on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: GovernancePage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('VIGILANCE MONITOR'), findsOneWidget);
    expect(find.text('COMPLIANCE ALERTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('governance page stays stable on landscape phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: GovernancePage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('VIGILANCE MONITOR'), findsOneWidget);
    expect(find.text('COMPLIANCE ALERTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('governance page renders persisted morning report metadata', (
    tester,
  ) async {
    final report = SovereignReport(
      date: '2026-03-10',
      generatedAtUtc: DateTime.utc(2026, 3, 10, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 9, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 10, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 184,
        hashVerified: true,
        integrityScore: 98,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 24,
        humanOverrides: 3,
        overrideReasons: {'PSIRA expired': 2},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 14,
        driftDetected: 2,
        avgMatchScore: 84,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 2,
        pdpExpired: 1,
        totalBlocked: 3,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GovernancePage(
          events: [],
          morningSovereignReport: report,
          morningSovereignReportAutoRunKey: '2026-03-10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Auto generated for shift ending 2026-03-10'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Generated 2026-03-10 06:00 UTC'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Override Reasons: PSIRA expired (2)'),
      findsOneWidget,
    );
    expect(find.text('Copy Morning JSON'), findsOneWidget);
    expect(find.text('Download Morning CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
