import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/presentation/reports/report_meta_pill.dart';

void main() {
  testWidgets('report meta pill renders label with shared shell styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportMetaPill(
            label: 'Scene 2',
            color: Color(0xFF63BDFF),
            fontSize: 11,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            backgroundOpacity: 0.1,
            borderOpacity: 0.3,
          ),
        ),
      ),
    );

    expect(find.text('Scene 2'), findsOneWidget);
  });

  testWidgets('report meta pill trims surrounding label whitespace', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportMetaPill(
            label: '  Scene 2  ',
            color: Color(0xFF63BDFF),
          ),
        ),
      ),
    );

    expect(find.text('Scene 2'), findsOneWidget);
    expect(find.text('  Scene 2  '), findsNothing);
  });

  testWidgets('report meta pill exposes active state styling flag', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportMetaPill(
            label: 'Latest Alert',
            color: Color(0xFF63BDFF),
            isActive: true,
          ),
        ),
      ),
    );

    final pill = tester.widget<ReportMetaPill>(find.byType(ReportMetaPill));
    expect(pill.isActive, isTrue);
  });
}
