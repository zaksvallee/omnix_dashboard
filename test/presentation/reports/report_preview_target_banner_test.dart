import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_preview_surface.dart';
import 'package:omnix_dashboard/presentation/reports/report_preview_target_banner.dart';

void main() {
  testWidgets('preview target banner renders label, surface, and actions', (
    tester,
  ) async {
    var opened = false;
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportPreviewTargetBanner(
            eventId: 'RPT-LIVE-1',
            previewSurface: ReportPreviewSurface.dock,
            surfaceLabelColor: const Color(0xFF8EA4C2),
            onOpen: () => opened = true,
            onClear: () => cleared = true,
            openButtonKey: const ValueKey('open-target'),
            clearButtonKey: const ValueKey('clear-target'),
          ),
        ),
      ),
    );

    expect(find.text('Preview target: RPT-LIVE-1'), findsOneWidget);
    expect(find.text('Docked'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-target')));
    await tester.tap(find.byKey(const ValueKey('clear-target')));

    expect(opened, isTrue);
    expect(cleared, isTrue);
  });

  testWidgets('preview target banner trims event id and falls back when blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ReportPreviewTargetBanner(
                eventId: '  RPT-LIVE-2  ',
                previewSurface: ReportPreviewSurface.route,
                surfaceLabelColor: const Color(0xFF8EA4C2),
                onClear: () {},
              ),
              ReportPreviewTargetBanner(
                eventId: '   ',
                previewSurface: ReportPreviewSurface.route,
                surfaceLabelColor: const Color(0xFF8EA4C2),
                onClear: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Preview target: RPT-LIVE-2'), findsOneWidget);
    expect(find.text('Preview target: Pending target'), findsOneWidget);
  });
}
