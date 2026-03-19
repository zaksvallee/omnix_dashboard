import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/presentation/reports_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reports page stays stable on phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ReportsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Reports & Documentation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports page stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ReportsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Reports & Documentation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports page renders command hub sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ReportsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Reports & Documentation'), findsOneWidget);
    expect(find.byKey(const ValueKey('reports-overview-grid')), findsOneWidget);
    expect(find.text('Report Generation Flow'), findsOneWidget);
    await tester.ensureVisible(find.text('Output Modules'));
    expect(find.text('Output Modules'), findsOneWidget);
    await tester.ensureVisible(find.text('Readiness Board'));
    expect(find.text('Readiness Board'), findsOneWidget);
    expect(find.text('Generate Deterministic PDF'), findsOneWidget);
    expect(find.text('Replay Verification'), findsOneWidget);
  });

  testWidgets('reports page generate action opens dialog and stages report', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ReportsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reports-generate-report-button')));
    await tester.pumpAndSettle();

    expect(find.text('Start Generation'), findsOneWidget);
    expect(find.text('Morning Sovereign'), findsWidgets);
    await tester.tap(find.text('Start Generation'));
    await tester.pumpAndSettle();

    expect(
      find.text('Report generation staged for command review.'),
      findsOneWidget,
    );
  });
}
