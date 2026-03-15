import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_output_mode.dart';
import 'package:omnix_dashboard/application/report_preview_request.dart';
import 'package:omnix_dashboard/application/report_preview_surface.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/application/report_shell_binding.dart';
import 'package:omnix_dashboard/application/report_shell_state.dart';
import 'package:omnix_dashboard/presentation/reports/report_shell_binding_host.dart';

import '../../fixtures/report_test_bundle.dart';
import '../../fixtures/report_test_receipt.dart';

void main() {
  testWidgets('host emits shell updates for shared mutations and prune flow', (
    tester,
  ) async {
    final emittedStates = <ReportShellState>[];

    await tester.pumpWidget(
      MaterialApp(
        home: _ReportShellBindingHostHarness(
          onShellStateChanged: emittedStates.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('host-set-filter')));
    await tester.pump();

    expect(
      emittedStates.last.receiptFilter,
      ReportReceiptSceneFilter.reviewed,
    );

    await tester.tap(find.byKey(const ValueKey('host-focus-receipt')));
    await tester.pump();

    expect(emittedStates.last.selectedReceiptEventId, 'RPT-2');
    expect(emittedStates.last.previewReceiptEventId, 'RPT-2');

    await tester.tap(find.byKey(const ValueKey('host-prune-receipts')));
    await tester.pump();

    expect(emittedStates.last.selectedReceiptEventId, 'RPT-2');
    expect(emittedStates.last.previewReceiptEventId, 'RPT-2');
    expect(find.text('rows:1'), findsOneWidget);
  });

  testWidgets('host skips shell emission for idempotent shared mutations', (
    tester,
  ) async {
    final emittedStates = <ReportShellState>[];

    await tester.pumpWidget(
      MaterialApp(
        home: _ReportShellBindingHostHarness(
          baseState: const ReportShellState(
            receiptFilter: ReportReceiptSceneFilter.reviewed,
          ),
          onShellStateChanged: emittedStates.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('host-set-filter')));
    await tester.pump();

    expect(emittedStates, isEmpty);
    expect(find.text('filter:reviewed'), findsOneWidget);
  });

  testWidgets('host forwards preview requests to shared callback when provided', (
    tester,
  ) async {
    ReportPreviewRequest? capturedRequest;
    final emittedStates = <ReportShellState>[];

    await tester.pumpWidget(
      MaterialApp(
        home: _ReportShellBindingHostHarness(
          onShellStateChanged: emittedStates.add,
          onRequestPreview: (request) => capturedRequest = request,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('host-preview-request')));
    await tester.pump();

    expect(capturedRequest, isNotNull);
    expect(capturedRequest!.receiptEvent?.eventId, 'RPT-9');
    expect(capturedRequest!.replayMatches, isTrue);
    expect(emittedStates, isEmpty);
  });

  testWidgets(
    'host forwards preview requests without receipt context without mutating shell state',
    (tester) async {
      ReportPreviewRequest? capturedRequest;
      final emittedStates = <ReportShellState>[];

      await tester.pumpWidget(
        MaterialApp(
          home: _ReportShellBindingHostHarness(
            baseState: const ReportShellState(
              selectedReceiptEventId: 'RPT-KEEP-1',
              previewReceiptEventId: 'RPT-KEEP-1',
              previewSurface: ReportPreviewSurface.dock,
            ),
            onShellStateChanged: emittedStates.add,
            onRequestPreview: (request) => capturedRequest = request,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('host-preview-request-no-receipt')));
      await tester.pump();

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.receiptEvent, isNull);
      expect(emittedStates, isEmpty);
      expect(find.text('selected:RPT-KEEP-1'), findsOneWidget);
      expect(find.text('preview:RPT-KEEP-1'), findsOneWidget);
    },
  );

  testWidgets('host fallback updates shell state and stays docked on dock surface', (
    tester,
  ) async {
    final emittedStates = <ReportShellState>[];

    await tester.pumpWidget(
      MaterialApp(
        home: _ReportShellBindingHostHarness(
          baseState: const ReportShellState(
            outputMode: ReportOutputMode.pdf,
            previewSurface: ReportPreviewSurface.dock,
          ),
          onShellStateChanged: emittedStates.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('host-preview-request')));
    await tester.pumpAndSettle();

    expect(emittedStates.last.selectedReceiptEventId, 'RPT-9');
    expect(emittedStates.last.previewReceiptEventId, 'RPT-9');
    expect(find.text('Scene Review Brief'), findsNothing);
    expect(find.text('rows:0'), findsOneWidget);
  });

  testWidgets('host fallback opens preview route on route surface', (
    tester,
  ) async {
    final emittedStates = <ReportShellState>[];

    await tester.pumpWidget(
      MaterialApp(
        home: _ReportShellBindingHostHarness(
          baseState: const ReportShellState(
            outputMode: ReportOutputMode.pdf,
            previewSurface: ReportPreviewSurface.route,
          ),
          onShellStateChanged: emittedStates.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('host-preview-request')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(emittedStates.last.selectedReceiptEventId, 'RPT-9');
    expect(emittedStates.last.previewReceiptEventId, 'RPT-9');
    expect(find.text('Scene Review Brief'), findsOneWidget);
  });

  testWidgets(
    'host fallback preserves existing selection for preview requests without receipt context',
    (tester) async {
      final emittedStates = <ReportShellState>[];

      await tester.pumpWidget(
        MaterialApp(
          home: _ReportShellBindingHostHarness(
            baseState: const ReportShellState(
              selectedReceiptEventId: 'RPT-KEEP-2',
              previewReceiptEventId: 'RPT-KEEP-2',
              outputMode: ReportOutputMode.pdf,
              previewSurface: ReportPreviewSurface.route,
            ),
            onShellStateChanged: emittedStates.add,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('host-preview-request-no-receipt')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(emittedStates, isEmpty);
      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsNothing);
    },
  );

  testWidgets(
    'host fallback avoids shell emission when preview targets the already-focused receipt',
    (tester) async {
      final emittedStates = <ReportShellState>[];

      await tester.pumpWidget(
        MaterialApp(
          home: _ReportShellBindingHostHarness(
            baseState: const ReportShellState(
              selectedReceiptEventId: 'RPT-9',
              previewReceiptEventId: 'RPT-9',
              outputMode: ReportOutputMode.pdf,
              previewSurface: ReportPreviewSurface.route,
            ),
            onShellStateChanged: emittedStates.add,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('host-preview-request')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(emittedStates, isEmpty);
      expect(find.text('Scene Review Brief'), findsOneWidget);
    },
  );
}

class _ReportShellBindingHostHarness extends StatefulWidget {
  final ReportShellState baseState;
  final ValueChanged<ReportShellState>? onShellStateChanged;
  final ValueChanged<ReportPreviewRequest>? onRequestPreview;

  const _ReportShellBindingHostHarness({
    this.baseState = const ReportShellState(
      outputMode: ReportOutputMode.pdf,
      previewSurface: ReportPreviewSurface.dock,
    ),
    this.onShellStateChanged,
    this.onRequestPreview,
  });

  @override
  State<_ReportShellBindingHostHarness> createState() =>
      _ReportShellBindingHostHarnessState();
}

class _ReportShellBindingHostHarnessState
    extends State<_ReportShellBindingHostHarness>
    with ReportShellBindingHost<_ReportShellBindingHostHarness> {
  late ReportShellBinding _binding;
  int _rowCount = 0;

  @override
  void initState() {
    super.initState();
    _binding = ReportShellBinding.fromShellState(widget.baseState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('rows:$_rowCount'),
          Text('filter:${reportShellBinding.receiptFilter.name}'),
          Text('selected:${reportShellBinding.selectedReceiptEventId ?? "-"}'),
          Text('preview:${reportShellBinding.previewReceiptEventId ?? "-"}'),
          TextButton(
            key: const ValueKey('host-set-filter'),
            onPressed: () => setReportReceiptFilter(
              ReportReceiptSceneFilter.reviewed,
            ),
            child: const Text('set filter'),
          ),
          TextButton(
            key: const ValueKey('host-focus-receipt'),
            onPressed: () => focusReportReceiptWorkspace('RPT-2'),
            child: const Text('focus receipt'),
          ),
          TextButton(
            key: const ValueKey('host-prune-receipts'),
            onPressed: () => syncPrunedReportShellBindingToReceiptIds(
              receiptEventIds: const {'RPT-2'},
              mutateLocalState: () => _rowCount = 1,
            ),
            child: const Text('prune receipts'),
          ),
          TextButton(
            key: const ValueKey('host-preview-request'),
            onPressed: () => presentReportPreviewRequest(_previewRequest()),
            child: const Text('preview request'),
          ),
          TextButton(
            key: const ValueKey('host-preview-request-no-receipt'),
            onPressed: () =>
                presentReportPreviewRequest(_previewRequestWithoutReceipt()),
            child: const Text('preview request no receipt'),
          ),
        ],
      ),
    );
  }

  @override
  ReportShellBinding get reportShellBinding => _binding;

  @override
  set reportShellBinding(ReportShellBinding value) => _binding = value;

  @override
  ReportShellState get reportShellBaseState => widget.baseState;

  @override
  ValueChanged<ReportShellState>? get onReportShellStateChanged =>
      widget.onShellStateChanged;

  @override
  ValueChanged<ReportPreviewRequest>? get onRequestPreview =>
      widget.onRequestPreview;
}

ReportPreviewRequest _previewRequest() {
  return ReportPreviewRequest(
    bundle: buildTestReportBundle(),
    initialPdfBytes: Uint8List.fromList(const [1, 2, 3]),
    receiptEvent: buildTestReportGenerated(
      eventId: 'RPT-9',
      sequence: 9,
      occurredAt: DateTime.utc(2026, 3, 14),
      reportSchemaVersion: 2,
      projectionVersion: 2,
    ),
    replayMatches: true,
  );
}

ReportPreviewRequest _previewRequestWithoutReceipt() {
  return ReportPreviewRequest(
    bundle: buildTestReportBundle(),
    initialPdfBytes: Uint8List.fromList(const [1, 2, 3]),
  );
}
