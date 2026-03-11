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

    expect(find.text('Reports Command Hub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports page stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ReportsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Reports Command Hub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports page renders command hub sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ReportsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Reports Command Hub'), findsOneWidget);
    expect(find.text('Report Generation Flow'), findsOneWidget);
    expect(find.text('Output Modules'), findsOneWidget);
    expect(find.text('Readiness Board'), findsOneWidget);
    expect(find.text('Generate Deterministic PDF'), findsOneWidget);
    expect(find.text('Replay Verification'), findsOneWidget);
  });
}
