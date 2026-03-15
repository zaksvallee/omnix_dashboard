import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/presentation/reports/report_status_badge.dart';

void main() {
  testWidgets('report status badge renders label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportStatusBadge(
            label: 'VERIFIED',
            textColor: Color(0xFF59D79B),
            backgroundColor: Color(0x2959D79B),
            borderColor: Color(0xFF59D79B),
            fontSize: 10,
          ),
        ),
      ),
    );

    expect(find.text('VERIFIED'), findsOneWidget);
  });

  testWidgets('report status badge trims surrounding label whitespace', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportStatusBadge(
            label: '  VERIFIED  ',
            textColor: Color(0xFF59D79B),
            backgroundColor: Color(0x2959D79B),
            borderColor: Color(0xFF59D79B),
          ),
        ),
      ),
    );

    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('  VERIFIED  '), findsNothing);
  });
}
