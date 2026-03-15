import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_entry_context.dart';
import 'package:omnix_dashboard/application/report_preview_request.dart';
import 'package:omnix_dashboard/presentation/reports/report_preview_presenter.dart';

import '../../fixtures/report_test_bundle.dart';
import '../../fixtures/report_test_receipt.dart';

void main() {
  testWidgets('report preview presenter pushes preview page onto navigator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                key: const ValueKey('open-preview'),
                onPressed: () {
                  ReportPreviewPresenter.present(
                    context,
                    ReportPreviewRequest(
                      bundle: buildTestReportBundle(),
                      initialPdfBytes: Uint8List.fromList(
                        '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'
                            .codeUnits,
                      ),
                      receiptEvent: buildTestReportGenerated(
                        eventId: 'RPT-PRESENTER-1',
                        reportSchemaVersion: 2,
                        projectionVersion: 2,
                      ),
                      replayMatches: true,
                    ),
                  );
                },
                child: const Text('Open Preview'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-preview')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Scene Review Brief'), findsOneWidget);
    expect(find.text('Notable Findings'), findsOneWidget);
    expect(
      find.textContaining('Person visible near the boundary'),
      findsOneWidget,
    );
  });

  testWidgets('report preview presenter preserves receipt replay context', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                key: const ValueKey('open-preview-failed'),
                onPressed: () {
                  ReportPreviewPresenter.present(
                    context,
                    ReportPreviewRequest(
                      bundle: buildTestReportBundle(),
                      initialPdfBytes: Uint8List.fromList(
                        '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'
                            .codeUnits,
                      ),
                      receiptEvent: buildTestReportGenerated(
                        eventId: 'RPT-PRESENTER-FAILED-1',
                        eventRangeStart: 12,
                        eventRangeEnd: 18,
                        reportSchemaVersion: 2,
                        projectionVersion: 2,
                      ),
                      replayMatches: false,
                    ),
                  );
                },
                child: const Text('Open Preview Failed'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-preview-failed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Receipt Integrity'), findsOneWidget);
    expect(find.textContaining('RPT-PRESENTER-FAILED-1'), findsWidgets);
    expect(find.textContaining('12-18'), findsWidgets);
    expect(find.textContaining('Failed'), findsWidgets);
  });

  testWidgets('report preview presenter carries governance entry context', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                key: const ValueKey('open-preview-governance'),
                onPressed: () {
                  ReportPreviewPresenter.present(
                    context,
                    ReportPreviewRequest(
                      bundle: buildTestReportBundle(),
                      initialPdfBytes: Uint8List.fromList(
                        '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'
                            .codeUnits,
                      ),
                      receiptEvent: buildTestReportGenerated(
                        eventId: 'RPT-PRESENTER-GOV-1',
                        reportSchemaVersion: 2,
                        projectionVersion: 2,
                      ),
                      entryContext: ReportEntryContext.governanceBrandingDrift,
                    ),
                  );
                },
                child: const Text('Open Preview Governance'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-preview-governance')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Preview Context'), findsOneWidget);
    expect(find.text('OPENED FROM GOVERNANCE BRANDING DRIFT'), findsOneWidget);
  });
}
