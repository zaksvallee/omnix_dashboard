import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_entry_context.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_branding_configuration.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_section_configuration.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_sections.dart';
import 'package:omnix_dashboard/presentation/reports/report_preview_page.dart';

import '../../fixtures/report_test_bundle.dart';
import '../../fixtures/report_test_receipt.dart';

class _NavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('report preview shows scene review brief summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportPreviewPage(
          bundle: buildTestReportBundle(
            brandingConfiguration: const ReportBrandingConfiguration(
              primaryLabel: 'VISION Tactical',
              endorsementLine: 'Powered by ONYX',
            ),
            sceneReview: const SceneReviewSnapshot(
              totalReviews: 2,
              modelReviews: 1,
              metadataFallbackReviews: 1,
              suppressedActions: 1,
              incidentAlerts: 0,
              repeatUpdates: 1,
              escalationCandidates: 1,
              topPosture: 'escalation candidate',
              latestActionTaken:
                  '2026-03-14T21:18:00.000Z • Camera 2 • Escalation Candidate • Escalated for urgent review because person activity was detected near the boundary.',
              latestSuppressedPattern:
                  '2026-03-14T21:16:00.000Z • Camera 3 • Vehicle remained below escalation threshold.',
              highlights: [
                SceneReviewHighlightSnapshot(
                  intelligenceId: 'intel-2',
                  detectedAt: '2026-03-14T21:18:00.000Z',
                  cameraLabel: 'Camera 2',
                  sourceLabel: 'metadata:fallback',
                  postureLabel: 'escalation candidate',
                  decisionLabel: 'Escalation Candidate',
                  decisionSummary:
                      'Escalated for urgent review because person activity was detected near the boundary.',
                  summary:
                      'Person visible near the boundary after repeat activity.',
                ),
              ],
            ),
          ),
          initialPdfBytes: Uint8List.fromList(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Scene Review Brief'), findsOneWidget);
    expect(find.text('Branding'), findsOneWidget);
    expect(find.text('VISION Tactical'), findsOneWidget);
    expect(find.text('Powered by ONYX'), findsOneWidget);
    expect(find.text('Report Configuration'), findsOneWidget);
    expect(
      _findRichTextContaining('AI Decision Log: INCLUDED'),
      findsOneWidget,
    );
    expect(find.textContaining('Latest action taken:'), findsOneWidget);
    expect(find.textContaining('Latest filtered pattern:'), findsOneWidget);
    expect(find.text('Notable Findings'), findsOneWidget);
    expect(
      find.textContaining(
        'ONYX action: Escalated for urgent review because person activity was detected near the boundary.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Person visible near the boundary'),
      findsOneWidget,
    );
  });

  testWidgets('report preview shows governance entry context when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportPreviewPage(
          bundle: buildTestReportBundle(),
          initialPdfBytes: Uint8List.fromList(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
          ),
          receiptEvent: buildTestReportGenerated(
            eventId: 'RPT-PREVIEW-GOV-1',
            reportSchemaVersion: 2,
            projectionVersion: 2,
          ),
          entryContext: ReportEntryContext.governanceBrandingDrift,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Preview Context'), findsOneWidget);
    expect(find.text('Governance Handoff PDF'), findsOneWidget);
    expect(find.textContaining('Governance handoff lane'), findsWidgets);
    expect(
      find.byKey(const ValueKey('report-preview-entry-context-banner')),
      findsOneWidget,
    );
    expect(find.text('OPENED FROM GOVERNANCE BRANDING DRIFT'), findsOneWidget);
    expect(
      find.textContaining(
        'This receipt scope was opened from Governance so operators can inspect the generated-report history behind a branding-drift shift.',
      ),
      findsOneWidget,
    );
    expect(find.text('GOVERNANCE HANDOFF'), findsWidgets);
    expect(_findRichTextContaining('Receipt: RPT-PREVIEW-GOV-1'), findsWidgets);
  });

  testWidgets('report preview shows omitted ai configuration note', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportPreviewPage(
          bundle: buildTestReportBundle(
            sectionConfiguration: const ReportSectionConfiguration(
              includeTimeline: true,
              includeDispatchSummary: true,
              includeCheckpointCompliance: true,
              includeAiDecisionLog: false,
              includeGuardMetrics: false,
            ),
          ),
          initialPdfBytes: Uint8List.fromList(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Report Configuration'), findsOneWidget);
    expect(_findRichTextContaining('AI Decision Log: OMITTED'), findsOneWidget);
    expect(_findRichTextContaining('Guard Metrics: OMITTED'), findsOneWidget);
    expect(
      find.textContaining('AI decision log was disabled for this report.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'report preview hides receipt integrity when no receipt is provided',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportPreviewPage(
            bundle: buildTestReportBundle(),
            initialPdfBytes: Uint8List.fromList(
              '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Receipt Integrity'), findsNothing);
      expect(find.text('Receipt'), findsNothing);
      expect(find.text('Replay'), findsNothing);
    },
  );

  testWidgets('report preview shows receipt integrity details when provided', (
    tester,
  ) async {
    final receipt = buildTestReportGenerated(
      eventId: 'RPT-PREVIEW-INTEGRITY-1',
      eventRangeStart: 7,
      eventRangeEnd: 19,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportPreviewPage(
          bundle: buildTestReportBundle(),
          initialPdfBytes: Uint8List.fromList(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
          ),
          receiptEvent: receipt,
          replayMatches: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Receipt Integrity'), findsOneWidget);
    expect(find.text('STANDARD RECEIPT EXPORT'), findsWidgets);
    expect(find.textContaining('RPT-PREVIEW-INTEGRITY-1'), findsWidgets);
    expect(find.textContaining('7-19'), findsWidgets);
    expect(find.textContaining('Matched'), findsWidgets);
  });

  testWidgets('report preview back action pops route', (tester) async {
    final observer = _NavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReportPreviewPage(
                      bundle: buildTestReportBundle(),
                      initialPdfBytes: Uint8List.fromList(
                        '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'
                            .codeUnits,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Operational Intelligence PDF'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();

    expect(observer.popCount, 1);
    expect(find.text('Operational Intelligence PDF'), findsNothing);
  });

  testWidgets('report preview print action invokes printing channel', (
    tester,
  ) async {
    MethodCall? capturedCall;
    final printingChannel = const MethodChannel('net.nfet.printing');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      printingChannel,
      (call) async {
        if (call.method == 'printingInfo') {
          return <String, dynamic>{
            'directPrint': false,
            'dynamicLayout': true,
            'canPrint': true,
            'canShare': true,
            'canRaster': false,
          };
        }
        if (call.method == 'printPdf') {
          capturedCall = call;
          return 1;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        printingChannel,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportPreviewPage(
          bundle: buildTestReportBundle(),
          initialPdfBytes: Uint8List.fromList(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
          ),
          receiptEvent: buildTestReportGenerated(
            eventId: 'RPT-PREVIEW-PRINT-1',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Print').first);
    await tester.pump();

    expect(capturedCall, isNotNull);
    expect(capturedCall?.method, 'printPdf');
    final args = capturedCall!.arguments as Map<dynamic, dynamic>;
    expect(args['name'], isA<String>());
    expect((args['name'] as String).isNotEmpty, isTrue);
    expect(args['job'], isNotNull);
    expect(args['outputType'], isNotNull);
  });

  testWidgets('report preview download action invokes share channel', (
    tester,
  ) async {
    MethodCall? capturedCall;
    final printingChannel = const MethodChannel('net.nfet.printing');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      printingChannel,
      (call) async {
        if (call.method == 'printingInfo') {
          return <String, dynamic>{
            'directPrint': false,
            'dynamicLayout': true,
            'canPrint': true,
            'canShare': true,
            'canRaster': false,
          };
        }
        if (call.method == 'sharePdf') {
          capturedCall = call;
          return 1;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        printingChannel,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportPreviewPage(
          bundle: buildTestReportBundle(),
          initialPdfBytes: Uint8List.fromList(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
          ),
          receiptEvent: buildTestReportGenerated(
            eventId: 'RPT-PREVIEW-DOWNLOAD-1',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Download').first);
    await tester.pump();

    expect(capturedCall, isNotNull);
    expect(capturedCall?.method, 'sharePdf');
    final args = capturedCall!.arguments as Map<dynamic, dynamic>;
    expect(args['name'], 'onyx_intelligence_report.pdf');
    expect(args['doc'], isA<Uint8List>());
    expect((args['doc'] as Uint8List).isNotEmpty, isTrue);
  });

  testWidgets(
    'report preview download action uses governance handoff filename when opened from governance',
    (tester) async {
      MethodCall? capturedCall;
      final printingChannel = const MethodChannel('net.nfet.printing');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        printingChannel,
        (call) async {
          if (call.method == 'printingInfo') {
            return <String, dynamic>{
              'directPrint': false,
              'dynamicLayout': true,
              'canPrint': true,
              'canShare': true,
              'canRaster': false,
            };
          }
          if (call.method == 'sharePdf') {
            capturedCall = call;
            return 1;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          printingChannel,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportPreviewPage(
            bundle: buildTestReportBundle(),
            initialPdfBytes: Uint8List.fromList(
              '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
            ),
            receiptEvent: buildTestReportGenerated(
              eventId: 'RPT-PREVIEW-DOWNLOAD-GOV-1',
            ),
            entryContext: ReportEntryContext.governanceBrandingDrift,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('Download').first);
      await tester.pump();

      expect(capturedCall, isNotNull);
      final args = capturedCall!.arguments as Map<dynamic, dynamic>;
      expect(args['name'], 'onyx_intelligence_report_governance_handoff.pdf');
    },
  );
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is! RichText) {
      return false;
    }
    return widget.text.toPlainText().contains(text);
  });
}
