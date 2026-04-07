import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/ui/risk_intelligence_page.dart';

void main() {
  testWidgets('risk intelligence page opens manual intel intake dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: RiskIntelligencePage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('intel-add-manual-button')),
    );
    await tester.tap(find.byKey(const ValueKey('intel-add-manual-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('intel-add-manual-dialog')),
      findsOneWidget,
    );
    expect(find.text('Intel Intake'), findsOneWidget);
    expect(find.text('INTAKE CHECKLIST'), findsOneWidget);
    expect(
      find.textContaining('Open Events Scope or Dispatch'),
      findsOneWidget,
    );
  });

  testWidgets(
    'risk intelligence page uses provided manual intel callback when available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RiskIntelligencePage(
            onAddManualIntel: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OPEN INTEL INTAKE'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('intel-add-manual-button')),
      );
      await tester.tap(find.byKey(const ValueKey('intel-add-manual-button')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(
        find.byKey(const ValueKey('intel-add-manual-dialog')),
        findsNothing,
      );
    },
  );

  testWidgets('risk intelligence page opens area posture dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: RiskIntelligencePage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('intel-area-sandton-button')),
    );
    await tester.tap(find.byKey(const ValueKey('intel-area-sandton-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('intel-area-sandton-dialog')),
      findsOneWidget,
    );
    expect(find.text('AREA POSTURE'), findsOneWidget);
    expect(find.text('Sandton'), findsWidgets);
    expect(find.text('Suggested Next Step'), findsOneWidget);
  });

  testWidgets('risk intelligence page opens recent intel detail dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: RiskIntelligencePage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('intel-detail-twitter-button')),
    );
    await tester.tap(find.byKey(const ValueKey('intel-detail-twitter-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('intel-detail-twitter-dialog')),
      findsOneWidget,
    );
    expect(find.text('TWITTER'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('intel-detail-twitter-dialog')),
        matching: find.text('23:15'),
      ),
      findsOneWidget,
    );
    expect(find.text('Triage Guidance'), findsOneWidget);
  });

  testWidgets('risk intelligence page shows signal-count CTA for scoped area', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: RiskIntelligencePage(
          areas: const [
            RiskIntelAreaSummary(
              title: 'Sandton',
              level: 'MEDIUM',
              accent: Color(0xFFFFC533),
              border: Color(0xFF70511F),
              signalCount: 2,
              eventIds: ['evt-1', 'evt-2'],
              selectedEventId: 'evt-1',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 live signals are pushing this lane.'), findsOneWidget);
    expect(find.text('OPEN EVENTS SCOPE'), findsAtLeastNWidgets(1));
  });

  testWidgets('risk intelligence page shows latest auto-audit receipt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var openedLatestAudit = false;

    await tester.pumpWidget(
      MaterialApp(
        home: RiskIntelligencePage(
          latestAutoAuditReceipt: const RiskIntelAutoAuditReceipt(
            auditId: 'INTEL-AUDIT-1',
            label: 'AUTO-AUDIT',
            headline: 'Risk Intel action signed automatically.',
            detail: 'Opened AI call from Risk Intel. • hash abc123def4',
            accent: Color(0xFF63E6A1),
          ),
          onOpenLatestAudit: () {
            openedLatestAudit = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('intel-latest-audit-panel')), findsOneWidget);
    expect(find.text('AUTO-AUDIT'), findsOneWidget);
    expect(
      find.text('Risk Intel action signed automatically.'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('intel-view-latest-audit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('intel-view-latest-audit-button')));
    await tester.pumpAndSettle();

    expect(openedLatestAudit, isTrue);
  });
}
