import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/ui/live_operations_page.dart';

void main() {
  testWidgets('live operations stays stable on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('INCIDENT QUEUE'), findsOneWidget);
    expect(find.text('SOVEREIGN LEDGER FEED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live operations stays stable on landscape phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('INCIDENT QUEUE'), findsOneWidget);
    expect(find.text('SOVEREIGN LEDGER FEED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live operations renders multi-incident layout panels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );

    expect(find.text('INCIDENT QUEUE'), findsOneWidget);
    expect(find.text('ACTION LADDER'), findsOneWidget);
    expect(find.text('INCIDENT CONTEXT'), findsOneWidget);
    expect(find.text('SOVEREIGN LEDGER FEED'), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-8829-QX')), findsOneWidget);
    expect(find.byKey(const Key('incident-card-INC-8830-RZ')), findsOneWidget);
  });

  testWidgets('manual override requires selecting a reason code', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveOperationsPage(events: [])),
    );

    await tester.ensureVisible(find.text('MANUAL OVERRIDE'));
    await tester.tap(find.text('MANUAL OVERRIDE'));
    await tester.pumpAndSettle();

    final submitFinder = find.byKey(const Key('override-submit-button'));
    expect(submitFinder, findsOneWidget);
    expect((tester.widget<FilledButton>(submitFinder)).onPressed, isNull);

    await tester.tap(find.byKey(const Key('reason-DUPLICATE_SIGNAL')));
    await tester.pumpAndSettle();

    expect((tester.widget<FilledButton>(submitFinder)).onPressed, isNotNull);

    await tester.tap(submitFinder);
    await tester.pumpAndSettle();
    expect(find.text('Select a reason code (required):'), findsNothing);
  });
}
