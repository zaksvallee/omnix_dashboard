import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_preview_request.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/application/report_preview_surface.dart';
import 'package:omnix_dashboard/application/report_shell_state.dart';
import 'package:omnix_dashboard/presentation/reports/report_preview_controller.dart';

import '../../fixtures/report_test_bundle.dart';
import '../../fixtures/report_test_receipt.dart';

void main() {
  test('syncPreviewSelection keeps shell state when receipt event is missing', () {
    const shellState = ReportShellState(
      receiptFilter: ReportReceiptSceneFilter.reviewed,
      selectedReceiptEventId: 'RPT-OLD',
      previewReceiptEventId: 'RPT-OLD',
      previewSurface: ReportPreviewSurface.dock,
    );

    final nextState = ReportPreviewController.syncPreviewSelection(
      shellState,
      receiptEventId: null,
    );

    expect(nextState.receiptFilter, shellState.receiptFilter);
    expect(nextState.selectedReceiptEventId, shellState.selectedReceiptEventId);
    expect(nextState.previewReceiptEventId, shellState.previewReceiptEventId);
    expect(nextState.previewSurface, shellState.previewSurface);
  });

  test('syncPreviewSelection focuses the requested receipt event', () {
    const shellState = ReportShellState(
      previewSurface: ReportPreviewSurface.route,
    );

    final nextState = ReportPreviewController.syncPreviewSelection(
      shellState,
      receiptEventId: 'RPT-LIVE-1',
    );

    expect(nextState.selectedReceiptEventId, 'RPT-LIVE-1');
    expect(nextState.previewReceiptEventId, 'RPT-LIVE-1');
    expect(nextState.previewSurface, ReportPreviewSurface.route);
  });

  test('syncPreviewSelection trims surrounding whitespace from receipt id', () {
    const shellState = ReportShellState(
      previewSurface: ReportPreviewSurface.route,
    );

    final nextState = ReportPreviewController.syncPreviewSelection(
      shellState,
      receiptEventId: '  RPT-LIVE-TRIM-1  ',
    );

    expect(nextState.selectedReceiptEventId, 'RPT-LIVE-TRIM-1');
    expect(nextState.previewReceiptEventId, 'RPT-LIVE-TRIM-1');
  });

  test('syncPreviewSelection keeps shell state when receipt is already focused and previewed', () {
    const shellState = ReportShellState(
      selectedReceiptEventId: 'RPT-LIVE-1',
      previewReceiptEventId: 'RPT-LIVE-1',
      previewSurface: ReportPreviewSurface.route,
    );

    final nextState = ReportPreviewController.syncPreviewSelection(
      shellState,
      receiptEventId: '  RPT-LIVE-1  ',
    );

    expect(identical(nextState, shellState), isTrue);
  });

  test('usesDockSurface reflects the report shell preview surface', () {
    const routeState = ReportShellState(
      previewSurface: ReportPreviewSurface.route,
    );
    const dockState = ReportShellState(
      previewSurface: ReportPreviewSurface.dock,
    );

    expect(ReportPreviewController.usesDockSurface(routeState), isFalse);
    expect(ReportPreviewController.usesDockSurface(dockState), isTrue);
  });

  testWidgets('handleRequest updates shell state and stays in place for dock surface', (
    tester,
  ) async {
    final emittedStates = <ReportShellState>[];
    BuildContext? capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const Scaffold(body: Text('Host'));
          },
        ),
      ),
    );

    ReportPreviewController.handleRequest(
      context: capturedContext!,
      request: _testPreviewRequest(),
      shellState: const ReportShellState(
        previewSurface: ReportPreviewSurface.dock,
      ),
      onReportShellStateChanged: emittedStates.add,
    );
    await tester.pump();

    expect(emittedStates.last.selectedReceiptEventId, 'RPT-CONTROLLER-1');
    expect(emittedStates.last.previewReceiptEventId, 'RPT-CONTROLLER-1');
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Scene Review Brief'), findsNothing);
  });

  testWidgets('handleRequest opens preview route for route surface', (
    tester,
  ) async {
    final emittedStates = <ReportShellState>[];
    BuildContext? capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const Scaffold(body: Text('Host'));
          },
        ),
      ),
    );

    ReportPreviewController.handleRequest(
      context: capturedContext!,
      request: _testPreviewRequest(),
      shellState: const ReportShellState(
        previewSurface: ReportPreviewSurface.route,
      ),
      onReportShellStateChanged: emittedStates.add,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(emittedStates.last.selectedReceiptEventId, 'RPT-CONTROLLER-1');
    expect(emittedStates.last.previewReceiptEventId, 'RPT-CONTROLLER-1');
    expect(find.text('Scene Review Brief'), findsOneWidget);
  });

  testWidgets(
    'handleRequest preserves existing selection when request has no receipt event',
    (tester) async {
      final emittedStates = <ReportShellState>[];
      BuildContext? capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: Text('Host'));
            },
          ),
        ),
      );

      ReportPreviewController.handleRequest(
        context: capturedContext!,
        request: ReportPreviewRequest(
          bundle: buildTestReportBundle(),
          initialPdfBytes: Uint8List.fromList(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
          ),
        ),
        shellState: const ReportShellState(
          selectedReceiptEventId: 'RPT-KEEP-1',
          previewReceiptEventId: 'RPT-KEEP-1',
          previewSurface: ReportPreviewSurface.route,
        ),
        onReportShellStateChanged: emittedStates.add,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(emittedStates, isEmpty);
      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsNothing);
    },
  );

  testWidgets(
    'handleRequest avoids shell emission when request targets the already-focused receipt',
    (tester) async {
      final emittedStates = <ReportShellState>[];
      BuildContext? capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: Text('Host'));
            },
          ),
        ),
      );

      ReportPreviewController.handleRequest(
        context: capturedContext!,
        request: ReportPreviewRequest(
          bundle: buildTestReportBundle(),
          initialPdfBytes: Uint8List.fromList(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
          ),
          receiptEvent: buildTestReportGenerated(
            eventId: 'RPT-SAME-1',
            reportSchemaVersion: 2,
            projectionVersion: 2,
          ),
        ),
        shellState: const ReportShellState(
          selectedReceiptEventId: 'RPT-SAME-1',
          previewReceiptEventId: 'RPT-SAME-1',
          previewSurface: ReportPreviewSurface.route,
        ),
        onReportShellStateChanged: emittedStates.add,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(emittedStates, isEmpty);
      expect(find.text('Scene Review Brief'), findsOneWidget);
    },
  );
}

ReportPreviewRequest _testPreviewRequest() {
  return ReportPreviewRequest(
    bundle: buildTestReportBundle(),
    initialPdfBytes: Uint8List.fromList(
      '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits,
    ),
    receiptEvent: buildTestReportGenerated(
      eventId: 'RPT-CONTROLLER-1',
      reportSchemaVersion: 2,
      projectionVersion: 2,
    ),
    replayMatches: true,
  );
}
