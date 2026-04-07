import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/report_output_mode.dart';
import 'package:omnix_dashboard/application/report_entry_context.dart';
import 'package:omnix_dashboard/application/report_preview_request.dart';
import 'package:omnix_dashboard/application/report_preview_surface.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/application/report_shell_state.dart';
import 'package:omnix_dashboard/domain/events/report_generated.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/presentation/reports/report_test_harness.dart';

import '../fixtures/report_test_receipt.dart';
import '../fixtures/report_test_bundle.dart';
import '../fixtures/report_test_reviewed_workspace.dart';

DateTime _reportHarnessOccurredAtUtc(int day, int hour, int minute) =>
    DateTime.utc(2026, 3, day, hour, minute);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('report test harness export all button is actionable', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-1',
        occurredAt: _reportHarnessOccurredAtUtc(14, 22, 0),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exportAllButton = find.byKey(
      const ValueKey('report-harness-export-all-button'),
    );
    await tester.ensureVisible(exportAllButton);
    await tester.tap(exportAllButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Exported 1 receipt records to clipboard.'),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"context"'));
    expect(clipboardText, contains('"receipts"'));
    expect(clipboardText, contains('"key": "all"'));
    expect(clipboardText, contains('"eventId": "RPT-HARNESS-1"'));
    expect(clipboardText, contains('"reportSchemaVersion": 1'));
    expect(clipboardText, contains('"sceneReviewIncluded": false'));
  });

  testWidgets(
    'report test harness export all includes latest-action lens context',
    (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final fixture = buildReviewedReportWorkspaceFixture();

      await tester.pumpWidget(
        MaterialApp(
          home: ReportTestHarnessPage(
            store: fixture.store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
            reportShellState: const ReportShellState(
              receiptFilter: ReportReceiptSceneFilter.latestAlerts,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exportAllButton = find.byKey(
        const ValueKey('report-harness-export-all-button'),
      );
      await tester.ensureVisible(exportAllButton);
      await tester.tap(exportAllButton);
      await tester.pumpAndSettle();

      expect(clipboardText, isNotNull);
      expect(clipboardText, contains('"key": "latestAlerts"'));
      expect(clipboardText, contains('"statusLabel": "Latest Alert receipts"'));
      expect(clipboardText, contains('"focusedReceipt"'));
      expect(
        clipboardText,
        contains('"eventId": "${fixture.reviewedReceiptEventId}"'),
      );
      expect(clipboardText, contains('"latestActionBucket": "alerts"'));
      expect(clipboardText, contains('"latestActionTaken": "'));
      expect(clipboardText, contains('Monitoring Alert'));
      expect(clipboardText, contains('Camera 1'));
    },
  );

  testWidgets('report test harness row copy exports single receipt payload', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-COPY-1',
        occurredAt: _reportHarnessOccurredAtUtc(14, 22, 0),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copyButton = find.byKey(
      const ValueKey('report-harness-receipt-copy-RPT-HARNESS-COPY-1'),
    );
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Receipt export copied for RPT-HARNESS-COPY-1.'),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"context"'));
    expect(clipboardText, contains('"receipts"'));
    expect(clipboardText, contains('"key": "all"'));
    expect(clipboardText, contains('"eventId": "RPT-HARNESS-COPY-1"'));
    expect(clipboardText, contains('"reportSchemaVersion": 1'));
    expect(clipboardText, contains('"sceneReviewIncluded": false'));
  });

  testWidgets('report test harness stays stable on phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Client Intelligence Reports'), findsOneWidget);
    expect(find.text('Reviewed'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Escalation'), findsOneWidget);
    expect(find.text('Suppressed'), findsOneWidget);
    expect(find.text('Scene Pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report test harness stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Client Intelligence Reports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report test harness filter shows filtered empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LEGACY-1',
        occurredAt: _reportHarnessOccurredAtUtc(14, 22, 0),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filter = find.byKey(const ValueKey('report-harness-receipt-filter'));
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Escalation').last);
    await tester.pumpAndSettle();

    expect(find.text('No receipts match the selected filter.'), findsOneWidget);
  });

  testWidgets('report test harness escalation KPI applies receipt filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-LEGACY-2',
        occurredAt: _reportHarnessOccurredAtUtc(14, 23, 0),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final escalationKpi = find.byKey(
      const ValueKey('report-harness-kpi-escalation'),
    );
    await tester.ensureVisible(escalationKpi);
    await tester.tap(escalationKpi);
    await tester.pumpAndSettle();

    expect(
      find.text('Client CLIENT-001 • Site SITE-SANDTON • Escalation receipts'),
      findsOneWidget,
    );
    expect(find.text('Viewing Escalation receipts (0/1)'), findsOneWidget);
    expect(find.text('No receipts match the selected filter.'), findsOneWidget);

    await tester.tap(escalationKpi);
    await tester.pumpAndSettle();

    expect(
      find.text('Client CLIENT-001 • Site SITE-SANDTON • Escalation receipts'),
      findsNothing,
    );
    expect(find.text('Viewing Escalation receipts (0/1)'), findsNothing);
    expect(find.text('No receipts match the selected filter.'), findsNothing);
  });

  testWidgets('report test harness suppressed KPI applies receipt filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = buildSuppressedReportWorkspaceFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: fixture.store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final suppressedKpi = find.byKey(
      const ValueKey('report-harness-kpi-suppressed'),
    );
    await tester.ensureVisible(suppressedKpi);
    await tester.tap(suppressedKpi);
    await tester.pumpAndSettle();

    expect(
      find.text('Client CLIENT-001 • Site SITE-SANDTON • Suppressed receipts'),
      findsOneWidget,
    );
    expect(find.text('Viewing Suppressed receipts (1/2)'), findsOneWidget);
    expect(
      find.textContaining(reportTestSuppressedDecisionSummary),
      findsOneWidget,
    );
    expect(find.text('No receipts match the selected filter.'), findsNothing);
  });

  testWidgets('report test harness repeat KPI applies receipt filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = buildRepeatReportWorkspaceFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: fixture.store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final repeatKpi = find.byKey(const ValueKey('report-harness-kpi-repeat'));
    await tester.ensureVisible(repeatKpi);
    await tester.tap(repeatKpi);
    await tester.pumpAndSettle();

    expect(
      find.text('Client CLIENT-001 • Site SITE-SANDTON • Repeat receipts'),
      findsOneWidget,
    );
    expect(find.text('Viewing Repeat receipts (1/2)'), findsOneWidget);
    expect(
      find.textContaining(
        'Scene review stayed below escalation threshold across 1 reviewed CCTV event with 1 repeat update.',
      ),
      findsOneWidget,
    );
    expect(find.text('No receipts match the selected filter.'), findsNothing);
  });

  testWidgets(
    'report test harness latest suppressed dropdown filter applies receipt filter',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = buildSuppressedReportWorkspaceFixture();

      await tester.pumpWidget(
        MaterialApp(
          home: ReportTestHarnessPage(
            store: fixture.store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final filter = find.byKey(
        const ValueKey('report-harness-receipt-filter'),
      );
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Latest Suppressed').last);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Client CLIENT-001 • Site SITE-SANDTON • Latest Suppressed receipts',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Viewing Latest Suppressed receipts (1/2)'),
        findsOneWidget,
      );
      expect(find.text('No receipts match the selected filter.'), findsNothing);
    },
  );

  testWidgets('report test harness latest action pill applies receipt filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = buildSuppressedReportWorkspaceFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: fixture.store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Latest Supp'));
    await tester.tap(find.text('Latest Supp').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Client CLIENT-001 • Site SITE-SANDTON • Latest Suppressed receipts',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Viewing Latest Suppressed receipts (1/2)'),
      findsOneWidget,
    );
  });

  testWidgets(
    'report test harness latest-action banner shortcut opens matching receipt preview',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture();
      final shellState = ValueNotifier(
        const ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.latestAlerts,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Open Focused Receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Focused Receipt'));
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.selectedReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.previewReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
    },
  );

  testWidgets(
    'report test harness latest-action banner copy exports focused receipt',
    (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final fixture = buildReviewedReportWorkspaceFixture();
      final shellState = ValueNotifier(
        const ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.latestAlerts,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Copy Focused Receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy Focused Receipt'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Receipt export copied for ${fixture.reviewedReceiptEventId}.',
        ),
        findsWidgets,
      );
      expect(clipboardText, isNotNull);
      expect(clipboardText, contains('"context"'));
      expect(clipboardText, contains('"receipts"'));
      expect(
        clipboardText,
        contains('"eventId": "${fixture.reviewedReceiptEventId}"'),
      );
    },
  );

  testWidgets(
    'report test harness latest-action filter control shortcut opens matching receipt preview',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture();
      final shellState = ValueNotifier(
        const ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.latestAlerts,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(
          const ValueKey('report-receipt-filter-control-open-focused'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('report-receipt-filter-control-open-focused'),
        ),
      );
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.selectedReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.previewReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
    },
  );

  testWidgets(
    'report test harness active latest action pill opens matching receipt preview',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture();
      final shellState = ValueNotifier(
        const ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.latestAlerts,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Latest Alert').first);
      await tester.tap(find.text('Latest Alert').first);
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.selectedReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
      expect(
        shellState.value.previewReceiptEventId,
        fixture.reviewedReceiptEventId,
      );
    },
  );

  testWidgets('report test harness honors seeded filter and reports changes', (
    tester,
  ) async {
    ReportShellState? changedState;

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            receiptFilter: ReportReceiptSceneFilter.pending,
          ),
          onReportShellStateChanged: (value) => changedState = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Client CLIENT-001 • Site SITE-SANDTON • Scene Pending receipts',
      ),
      findsOneWidget,
    );

    final allKpi = find.byKey(const ValueKey('report-harness-kpi-all'));
    await tester.ensureVisible(allKpi);
    await tester.tap(allKpi);
    await tester.pumpAndSettle();

    expect(changedState?.receiptFilter, ReportReceiptSceneFilter.all);
    expect(
      find.text(
        'Client CLIENT-001 • Site SITE-SANDTON • Scene Pending receipts',
      ),
      findsNothing,
    );
  });

  testWidgets('report test harness syncs receipt filter from parent updates', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ReportTestHarnessPage(
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    shellState.value = shellState.value.copyWith(
      receiptFilter: ReportReceiptSceneFilter.pending,
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Client CLIENT-001 • Site SITE-SANDTON • Scene Pending receipts',
      ),
      findsOneWidget,
    );
    expect(find.text('No ReportGenerated receipts yet.'), findsOneWidget);
  });

  testWidgets('report test harness syncs preview surface from parent updates', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-1',
        occurredAt: _reportHarnessOccurredAtUtc(14, 23, 30),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ReportTestHarnessPage(
              store: store,
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    shellState.value = shellState.value.copyWith(
      previewReceiptEventId: 'RPT-HARNESS-1',
      previewSurface: ReportPreviewSurface.dock,
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Dock'), findsOneWidget);
    expect(find.text('Docked'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report-harness-preview-dock-open')),
      findsOneWidget,
    );
  });

  testWidgets('report test harness reflects focused receipt from shell state', (
    tester,
  ) async {
    final shellState = ValueNotifier(
      const ReportShellState(selectedReceiptEventId: 'RPT-HARNESS-FOCUS-1'),
    );
    addTearDown(shellState.dispose);
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-FOCUS-1',
        occurredAt: _reportHarnessOccurredAtUtc(14, 23, 40),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ReportTestHarnessPage(
              store: store,
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Selected Receipt'), findsOneWidget);
    expect(find.text('FOCUSED'), findsNWidgets(2));
  });

  testWidgets(
    'report test harness restores focused reviewed receipt after filter detour',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-FILTER-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-FILTER-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-FILTER-REVIEWED-1',
        intelligenceId: 'intel-harness-filter-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('Open Selected Receipt'), findsOneWidget);

      final escalationKpi = find.byKey(
        const ValueKey('report-harness-kpi-escalation'),
      );
      await tester.ensureVisible(escalationKpi);
      await tester.tap(escalationKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Escalation receipts (0/2)'), findsOneWidget);
      expect(
        find.text('No receipts match the selected filter.'),
        findsOneWidget,
      );
      expect(find.text('No Receipt Selected'), findsOneWidget);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);

      final reviewedKpi = find.byKey(
        const ValueKey('report-harness-kpi-reviewed'),
      );
      await tester.ensureVisible(reviewedKpi);
      await tester.tap(reviewedKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('Open Selected Receipt'), findsOneWidget);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'report test harness restores reviewed preview target after filter detour',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-FILTER-TARGET-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-FILTER-TARGET-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-FILTER-TARGET-REVIEWED-1',
        intelligenceId: 'intel-harness-filter-target-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewReceiptEventId: reviewedReceiptEventId,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);

      final escalationKpi = find.byKey(
        const ValueKey('report-harness-kpi-escalation'),
      );
      await tester.ensureVisible(escalationKpi);
      await tester.tap(escalationKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Escalation receipts (0/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(
        find.text('No receipts match the selected filter.'),
        findsOneWidget,
      );
      expect(find.text('No Receipt Selected'), findsOneWidget);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);

      final reviewedKpi = find.byKey(
        const ValueKey('report-harness-kpi-reviewed'),
      );
      await tester.ensureVisible(reviewedKpi);
      await tester.tap(reviewedKpi);
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'report test harness preserves reviewed target across preview surface switches',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-SURFACE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-SURFACE-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-SURFACE-REVIEWED-1',
        intelligenceId: 'intel-harness-surface-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewReceiptEventId: reviewedReceiptEventId,
          previewSurface: ReportPreviewSurface.route,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);

      final dockControl = find.byKey(
        const ValueKey('report-harness-preview-surface-dock'),
      );
      await tester.ensureVisible(dockControl);
      await tester.tap(dockControl);
      await tester.pumpAndSettle();

      expect(shellState.value.previewSurface, ReportPreviewSurface.dock);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
      expect(find.text('Preview Dock'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Full Preview'), findsWidgets);

      final routeControl = find.byKey(
        const ValueKey('report-harness-preview-surface-route'),
      );
      await tester.ensureVisible(routeControl);
      await tester.tap(routeControl);
      await tester.pumpAndSettle();

      expect(shellState.value.previewSurface, ReportPreviewSurface.route);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
      expect(find.text('Preview Dock'), findsNothing);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);
    },
  );

  testWidgets('report test harness output mode control updates shell state', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ReportTestHarnessPage(
              store: InMemoryEventStore(),
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
              onReportShellStateChanged: (next) => shellState.value = next,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final jsonControl = find.byKey(
      const ValueKey('report-harness-output-mode-json'),
    );
    await tester.ensureVisible(jsonControl);
    await tester.tap(jsonControl);
    await tester.pumpAndSettle();

    expect(shellState.value.outputMode, ReportOutputMode.json);
    expect(find.text('JSON'), findsWidgets);
  });

  testWidgets(
    'report test harness preserves reviewed target across output mode switches',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-OUTPUT-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-OUTPUT-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-OUTPUT-REVIEWED-1',
        intelligenceId: 'intel-harness-output-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewReceiptEventId: reviewedReceiptEventId,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);

      final jsonControl = find.byKey(
        const ValueKey('report-harness-output-mode-json'),
      );
      await tester.ensureVisible(jsonControl);
      await tester.tap(jsonControl);
      await tester.pumpAndSettle();

      expect(shellState.value.outputMode, ReportOutputMode.json);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
      expect(find.text('JSON'), findsWidgets);
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text('Open Preview Target'), findsOneWidget);
    },
  );

  testWidgets(
    'report test harness preview surface control updates shell state',
    (tester) async {
      final shellState = ValueNotifier(
        const ReportShellState(previewReceiptEventId: 'RPT-HARNESS-CTRL-1'),
      );
      addTearDown(shellState.dispose);
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-HARNESS-CTRL-1',
          occurredAt: _reportHarnessOccurredAtUtc(14, 23, 35),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          reportSchemaVersion: 1,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preview Dock'), findsNothing);

      final dockControl = find.byKey(
        const ValueKey('report-harness-preview-surface-dock'),
      );
      await tester.ensureVisible(dockControl);
      await tester.tap(dockControl);
      await tester.pumpAndSettle();

      expect(shellState.value.previewSurface, ReportPreviewSurface.dock);
      expect(find.text('Preview Dock'), findsOneWidget);
      expect(find.text('Docked'), findsOneWidget);
    },
  );

  testWidgets('report test harness preview target clear updates shell state', (
    tester,
  ) async {
    final shellState = ValueNotifier(const ReportShellState());
    addTearDown(shellState.dispose);
    ReportShellState? changedState;
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-2',
        occurredAt: _reportHarnessOccurredAtUtc(14, 23, 45),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ReportTestHarnessPage(
              store: store,
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
              onReportShellStateChanged: (next) {
                changedState = next;
                shellState.value = next;
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    shellState.value = shellState.value.copyWith(
      previewReceiptEventId: 'RPT-HARNESS-2',
      previewSurface: ReportPreviewSurface.dock,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('report-harness-preview-target-clear')),
    );
    await tester.pumpAndSettle();

    expect(changedState?.previewReceiptEventId, isNull);
    expect(find.text('Preview target: RPT-HARNESS-2'), findsNothing);
  });

  testWidgets(
    'report test harness preview target clear keeps reviewed receipt focused',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-CLEAR-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-CLEAR-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-CLEAR-REVIEWED-1',
        intelligenceId: 'intel-harness-clear-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewReceiptEventId: reviewedReceiptEventId,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('report-harness-preview-target-clear')),
      );
      await tester.pumpAndSettle();

      expect(shellState.value.previewReceiptEventId, isNull);
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsNothing,
      );
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('Open Selected Receipt'), findsOneWidget);
    },
  );

  testWidgets('report test harness dock clear updates shell state', (
    tester,
  ) async {
    final shellState = ValueNotifier(
      const ReportShellState(
        previewReceiptEventId: 'RPT-HARNESS-DOCK-CLEAR-1',
        previewSurface: ReportPreviewSurface.dock,
      ),
    );
    addTearDown(shellState.dispose);
    ReportShellState? changedState;
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-DOCK-CLEAR-1',
        occurredAt: _reportHarnessOccurredAtUtc(15, 0, 25),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ReportTestHarnessPage(
              store: store,
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              reportShellState: value,
              onReportShellStateChanged: (next) {
                changedState = next;
                shellState.value = next;
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Dock'), findsOneWidget);

    final dockClear = find.byKey(
      const ValueKey('report-harness-preview-dock-clear'),
    );
    await tester.ensureVisible(dockClear);
    await tester.tap(dockClear);
    await tester.pumpAndSettle();

    expect(changedState?.previewReceiptEventId, isNull);
    expect(find.text('Preview Dock'), findsNothing);
  });

  testWidgets('report test harness dock clear keeps reviewed receipt focused', (
    tester,
  ) async {
    final fixture = buildReviewedReportWorkspaceFixture(
      reviewedReceiptEventId: 'RPT-HARNESS-DOCK-CLEAR-REVIEWED-1',
      pendingReceiptEventId: 'RPT-HARNESS-DOCK-CLEAR-PENDING-1',
      intelligenceEventId: 'INTEL-HARNESS-DOCK-CLEAR-REVIEWED-1',
      intelligenceId: 'intel-harness-dock-clear-reviewed-1',
    );
    final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
    final shellState = ValueNotifier(
      ReportShellState(
        receiptFilter: ReportReceiptSceneFilter.reviewed,
        selectedReceiptEventId: reviewedReceiptEventId,
        previewReceiptEventId: reviewedReceiptEventId,
        previewSurface: ReportPreviewSurface.dock,
      ),
    );
    addTearDown(shellState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ReportShellState>(
          valueListenable: shellState,
          builder: (context, value, _) {
            return ReportTestHarnessPage(
              store: fixture.store,
              selectedClient: 'CLIENT-001',
              selectedSite: 'SITE-SANDTON',
              sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
              reportShellState: value,
              onReportShellStateChanged: (next) => shellState.value = next,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview Dock'), findsOneWidget);
    expect(
      find.text('Preview target: $reviewedReceiptEventId'),
      findsOneWidget,
    );

    final dockClear = find.byKey(
      const ValueKey('report-harness-preview-dock-clear'),
    );
    await tester.ensureVisible(dockClear);
    await tester.tap(dockClear);
    await tester.pumpAndSettle();

    expect(shellState.value.previewReceiptEventId, isNull);
    expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
    expect(find.text('Preview Dock'), findsNothing);
    expect(find.text('Preview target: $reviewedReceiptEventId'), findsNothing);
    expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
    expect(find.text('Open Selected Receipt'), findsOneWidget);
  });

  testWidgets(
    'report test harness uses shared preview callback when provided',
    (tester) async {
      ReportPreviewRequest? previewRequest;
      ReportShellState? changedState;
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-HARNESS-CALLBACK',
          occurredAt: _reportHarnessOccurredAtUtc(15, 0, 0),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          reportSchemaVersion: 1,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportTestHarnessPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            onReportShellStateChanged: (next) => changedState = next,
            onRequestPreview: (value) => previewRequest = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final callbackReceipt = find.text('RPT-HARNESS-CALLBACK');
      await tester.ensureVisible(callbackReceipt);
      await tester.tap(callbackReceipt);
      await tester.pumpAndSettle();

      expect(previewRequest?.receiptEvent?.eventId, 'RPT-HARNESS-CALLBACK');
      expect(changedState?.selectedReceiptEventId, 'RPT-HARNESS-CALLBACK');
    },
  );

  testWidgets('report test harness dock open triggers preview request', (
    tester,
  ) async {
    ReportPreviewRequest? previewRequest;
    ReportShellState? changedState;
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-DOCK-OPEN-1',
        occurredAt: _reportHarnessOccurredAtUtc(15, 0, 45),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            previewReceiptEventId: 'RPT-HARNESS-DOCK-OPEN-1',
            previewSurface: ReportPreviewSurface.dock,
          ),
          onReportShellStateChanged: (next) => changedState = next,
          onRequestPreview: (value) => previewRequest = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dockOpen = find.byKey(
      const ValueKey('report-harness-preview-dock-open'),
    );
    await tester.ensureVisible(dockOpen);
    await tester.tap(dockOpen);
    await tester.pumpAndSettle();

    expect(previewRequest?.receiptEvent?.eventId, 'RPT-HARNESS-DOCK-OPEN-1');
    expect(changedState?.selectedReceiptEventId, 'RPT-HARNESS-DOCK-OPEN-1');
    expect(changedState?.previewReceiptEventId, 'RPT-HARNESS-DOCK-OPEN-1');
    expect(find.text('Scene Review Brief'), findsNothing);
    expect(find.text('Preview Dock'), findsOneWidget);
    expect(
      find.text('Preview target: RPT-HARNESS-DOCK-OPEN-1'),
      findsOneWidget,
    );
  });

  testWidgets(
    'report test harness dock open stays docked without preview callback',
    (tester) async {
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-HARNESS-DOCK-ROUTE-1',
          occurredAt: _reportHarnessOccurredAtUtc(15, 0, 55),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          reportSchemaVersion: 2,
          projectionVersion: 2,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportTestHarnessPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            reportShellState: const ReportShellState(
              previewReceiptEventId: 'RPT-HARNESS-DOCK-ROUTE-1',
              previewSurface: ReportPreviewSurface.dock,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preview Dock'), findsOneWidget);

      final dockOpen = find.byKey(
        const ValueKey('report-harness-preview-dock-open'),
      );
      await tester.ensureVisible(dockOpen);
      await tester.tap(dockOpen);
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(find.text('Preview Dock'), findsOneWidget);
      expect(
        find.text('Preview target: RPT-HARNESS-DOCK-ROUTE-1'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'report test harness governance preview surfaces use governance wording',
    (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-HARNESS-GOV-1',
          occurredAt: _reportHarnessOccurredAtUtc(15, 0, 55),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          reportSchemaVersion: 2,
          projectionVersion: 2,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportTestHarnessPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            reportShellState: const ReportShellState(
              previewReceiptEventId: 'RPT-HARNESS-GOV-1',
              previewSurface: ReportPreviewSurface.dock,
              entryContext: ReportEntryContext.governanceBrandingDrift,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Governance Receipt Handoff'), findsOneWidget);
      expect(find.text('Governance Preview Dock'), findsOneWidget);
      expect(find.text('Preview Governance PDF'), findsOneWidget);
      expect(find.text('Export Governance Receipts'), findsOneWidget);
      expect(
        find.textContaining(
          'Governance handoff • Client CLIENT-001 • Site SITE-SANDTON',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Use the actions above to preview, verify, and export the Governance handoff receipt history',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Keep Governance generation, replay, and operator review distinct during oversight handoff handling.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open Governance Preview'), findsWidgets);
      expect(find.text('Copy Governance Receipt'), findsWidgets);
      expect(find.text('Clear Governance Target'), findsWidgets);
      expect(find.text('Open Governance Preview'), findsWidgets);
      expect(find.text('Copy Governance Receipt'), findsWidgets);
      expect(find.text('Copy Receipt'), findsNothing);
      expect(find.text('Open Full Preview'), findsNothing);
      expect(find.text('Preview Report'), findsNothing);
      expect(find.text('Export All'), findsNothing);
      expect(find.text('Client Intelligence Reports'), findsNothing);

      final exportAllButton = find.byKey(
        const ValueKey('report-harness-export-all-button'),
      );
      await tester.ensureVisible(exportAllButton);
      await tester.tap(exportAllButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Governance receipt export copied for 1 receipt records.',
        ),
        findsWidgets,
      );
      expect(
        clipboardText,
        contains('"exportModeLabel": "GOVERNANCE HANDOFF"'),
      );
      expect(clipboardText, contains('"entryContext"'));

      final dockCopy = find.byKey(
        const ValueKey('report-harness-preview-dock-copy'),
      );
      await tester.ensureVisible(dockCopy);
      await tester.tap(dockCopy);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Governance receipt export copied for RPT-HARNESS-GOV-1.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets('report test harness dock copy exports targeted receipt', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-DOCK-COPY-1',
        occurredAt: _reportHarnessOccurredAtUtc(15, 0, 55),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 2,
        projectionVersion: 2,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            previewReceiptEventId: 'RPT-HARNESS-DOCK-COPY-1',
            previewSurface: ReportPreviewSurface.dock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dockCopy = find.byKey(
      const ValueKey('report-harness-preview-dock-copy'),
    );
    await tester.ensureVisible(dockCopy);
    await tester.tap(dockCopy);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Receipt export copied for RPT-HARNESS-DOCK-COPY-1.'),
      findsWidgets,
    );
    expect(clipboardText, contains('"eventId": "RPT-HARNESS-DOCK-COPY-1"'));
  });

  testWidgets('report test harness review lane opens focused receipt', (
    tester,
  ) async {
    ReportPreviewRequest? previewRequest;
    ReportShellState? changedState;
    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-LANE-1',
        occurredAt: _reportHarnessOccurredAtUtc(15, 0, 35),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            selectedReceiptEventId: 'RPT-HARNESS-LANE-1',
          ),
          onReportShellStateChanged: (next) => changedState = next,
          onRequestPreview: (value) => previewRequest = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reviewAction = find.text('Open Selected Receipt').first;
    await tester.ensureVisible(reviewAction);
    await tester.tap(reviewAction);
    await tester.pumpAndSettle();

    expect(previewRequest?.receiptEvent?.eventId, 'RPT-HARNESS-LANE-1');
    expect(changedState?.selectedReceiptEventId, 'RPT-HARNESS-LANE-1');
  });

  testWidgets('report test harness review lane copy exports focused receipt', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final store = InMemoryEventStore();
    store.append(
      buildTestReportGenerated(
        eventId: 'RPT-HARNESS-LANE-COPY-1',
        occurredAt: _reportHarnessOccurredAtUtc(15, 0, 35),
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        reportSchemaVersion: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportTestHarnessPage(
          store: store,
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
          reportShellState: const ReportShellState(
            selectedReceiptEventId: 'RPT-HARNESS-LANE-COPY-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copyAction = find.byKey(
      const ValueKey('report-harness-review-copy-button'),
    );
    await tester.ensureVisible(copyAction);
    await tester.tap(copyAction);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Receipt export copied for RPT-HARNESS-LANE-COPY-1.'),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"context"'));
    expect(clipboardText, contains('"receipts"'));
    expect(clipboardText, contains('"eventId": "RPT-HARNESS-LANE-COPY-1"'));
  });

  testWidgets(
    'report test harness preview target emits reviewed scene payload for reviewed receipt',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-TARGET-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-TARGET-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-TARGET-REVIEWED-1',
        intelligenceId: 'intel-harness-target-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          previewReceiptEventId: reviewedReceiptEventId,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );

      final openTarget = find.byKey(
        const ValueKey('report-harness-preview-target-open'),
      );
      await tester.ensureVisible(openTarget);
      await tester.tap(openTarget);
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        reviewedReceiptEventId,
      );
      expect(previewRequests.single.bundle.sceneReview.totalReviews, 1);
      expect(
        previewRequests.single.bundle.sceneReview.highlights.single.summary,
        reportTestSuppressedDecisionSummary,
      );
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'report test harness preview target copy exports targeted receipt',
    (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-HARNESS-TARGET-COPY-1',
          occurredAt: _reportHarnessOccurredAtUtc(15, 0, 40),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          reportSchemaVersion: 1,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportTestHarnessPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            reportShellState: const ReportShellState(
              previewReceiptEventId: 'RPT-HARNESS-TARGET-COPY-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copyTarget = find.byKey(
        const ValueKey('report-harness-preview-target-copy'),
      );
      await tester.ensureVisible(copyTarget);
      await tester.tap(copyTarget);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Receipt export copied for RPT-HARNESS-TARGET-COPY-1.',
        ),
        findsWidgets,
      );
      expect(clipboardText, contains('"eventId": "RPT-HARNESS-TARGET-COPY-1"'));
    },
  );

  testWidgets(
    'report test harness preview target opens reviewed preview route and returns focused',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-TARGET-ROUTE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-TARGET-ROUTE-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-TARGET-ROUTE-REVIEWED-1',
        intelligenceId: 'intel-harness-target-route-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          previewReceiptEventId: reviewedReceiptEventId,
          previewSurface: ReportPreviewSurface.route,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openTarget = find.byKey(
        const ValueKey('report-harness-preview-target-open'),
      );
      await tester.ensureVisible(openTarget);
      await tester.tap(openTarget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsOneWidget);
      expect(find.textContaining(reviewedReceiptEventId), findsWidgets);
      expect(
        find.textContaining(reportTestSuppressedDecisionSummary),
        findsOneWidget,
      );

      Navigator.of(tester.element(find.text('Scene Review Brief'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'report test harness review lane emits reviewed scene payload for focused reviewed receipt',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-LANE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-LANE-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-LANE-REVIEWED-1',
        intelligenceId: 'intel-harness-lane-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
        ),
      );
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text('Open Selected Receipt'), findsOneWidget);

      final reviewAction = find.text('Open Selected Receipt').first;
      await tester.ensureVisible(reviewAction);
      await tester.tap(reviewAction);
      await tester.pumpAndSettle();

      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        reviewedReceiptEventId,
      );
      expect(previewRequests.single.bundle.sceneReview.totalReviews, 1);
      expect(
        previewRequests.single.bundle.sceneReview.highlights.single.summary,
        reportTestSuppressedDecisionSummary,
      );
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'report test harness review lane opens reviewed preview route and returns focused',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-LANE-ROUTE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-LANE-ROUTE-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-LANE-ROUTE-REVIEWED-1',
        intelligenceId: 'intel-harness-lane-route-reviewed-1',
      );
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final shellState = ValueNotifier(
        ReportShellState(
          receiptFilter: ReportReceiptSceneFilter.reviewed,
          selectedReceiptEventId: reviewedReceiptEventId,
          previewSurface: ReportPreviewSurface.route,
        ),
      );
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: fixture.store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reviewAction = find.text('Open Selected Receipt').first;
      await tester.ensureVisible(reviewAction);
      await tester.tap(reviewAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsOneWidget);
      expect(find.textContaining(reviewedReceiptEventId), findsWidgets);
      expect(
        find.textContaining(reportTestSuppressedDecisionSummary),
        findsOneWidget,
      );

      Navigator.of(tester.element(find.text('Scene Review Brief'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
    },
  );

  testWidgets(
    'report test harness opens preview route when no callback is provided in route mode',
    (tester) async {
      final store = InMemoryEventStore();
      store.append(
        buildTestReportGenerated(
          eventId: 'RPT-HARNESS-ROUTE-1',
          occurredAt: _reportHarnessOccurredAtUtc(15, 0, 10),
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          reportSchemaVersion: 2,
          projectionVersion: 2,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportTestHarnessPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            reportShellState: const ReportShellState(
              previewSurface: ReportPreviewSurface.route,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final routeReceipt = find.text('RPT-HARNESS-ROUTE-1');
      await tester.ensureVisible(routeReceipt);
      await tester.tap(routeReceipt);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt'), findsOneWidget);
    },
  );

  testWidgets(
    'report test harness supports a reviewed dock workflow end to end',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-REVIEWED-1',
        intelligenceId: 'intel-harness-reviewed-1',
      );
      final store = fixture.store;
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;
      final pendingReceiptEventId = fixture.pendingReceiptEventId;

      final shellState = ValueNotifier(const ReportShellState());
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reviewedKpi = find.byKey(
        const ValueKey('report-harness-kpi-reviewed'),
      );
      await tester.ensureVisible(reviewedKpi);
      await tester.tap(reviewedKpi);
      await tester.pumpAndSettle();

      expect(
        find.text('Client CLIENT-001 • Site SITE-SANDTON • Reviewed receipts'),
        findsOneWidget,
      );
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
      expect(find.text(reviewedReceiptEventId), findsOneWidget);
      expect(find.text(pendingReceiptEventId), findsNothing);

      final dockControl = find.byKey(
        const ValueKey('report-harness-preview-surface-dock'),
      );
      await tester.ensureVisible(dockControl);
      await tester.tap(dockControl);
      await tester.pumpAndSettle();

      expect(shellState.value.previewSurface, ReportPreviewSurface.dock);

      final reviewedReceipt = find.text(reviewedReceiptEventId);
      await tester.ensureVisible(reviewedReceipt);
      await tester.tap(reviewedReceipt);
      await tester.pumpAndSettle();

      expect(
        previewRequests.single.receiptEvent?.eventId,
        reviewedReceiptEventId,
      );
      expect(previewRequests.single.bundle.sceneReview.totalReviews, 1);
      expect(
        previewRequests.single.bundle.sceneReview.highlights.single.summary,
        reportTestSuppressedDecisionSummary,
      );
      expect(shellState.value.selectedReceiptEventId, reviewedReceiptEventId);
      expect(shellState.value.previewReceiptEventId, reviewedReceiptEventId);
      expect(find.text('Alert 1'), findsOneWidget);
      expect(find.text('Latest Alert'), findsOneWidget);
      expect(find.textContaining('Latest action taken:'), findsOneWidget);
      expect(find.text('Preview Dock'), findsOneWidget);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'report test harness opens reviewed receipt into preview route end to end',
    (tester) async {
      final fixture = buildReviewedReportWorkspaceFixture(
        reviewedReceiptEventId: 'RPT-HARNESS-ROUTE-REVIEWED-1',
        pendingReceiptEventId: 'RPT-HARNESS-ROUTE-PENDING-1',
        intelligenceEventId: 'INTEL-HARNESS-ROUTE-REVIEWED-1',
        intelligenceId: 'intel-harness-route-reviewed-1',
      );
      final store = fixture.store;
      final reviewedReceiptEventId = fixture.reviewedReceiptEventId;

      await tester.pumpWidget(
        MaterialApp(
          home: ReportTestHarnessPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
            reportShellState: const ReportShellState(
              previewSurface: ReportPreviewSurface.route,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reviewedKpi = find.byKey(
        const ValueKey('report-harness-kpi-reviewed'),
      );
      await tester.ensureVisible(reviewedKpi);
      await tester.tap(reviewedKpi);
      await tester.pumpAndSettle();

      final reviewedReceipt = find.text(reviewedReceiptEventId);
      await tester.ensureVisible(reviewedReceipt);
      await tester.tap(reviewedReceipt);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsOneWidget);
      expect(find.textContaining(reviewedReceiptEventId), findsWidgets);
      expect(
        find.textContaining(reportTestSuppressedDecisionSummary),
        findsOneWidget,
      );

      Navigator.of(tester.element(find.text('Scene Review Brief'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(
        find.text('Preview target: $reviewedReceiptEventId'),
        findsOneWidget,
      );
      expect(find.text(reviewedReceiptEventId), findsWidgets);
      expect(find.text('Viewing Reviewed receipts (1/2)'), findsOneWidget);
    },
  );

  testWidgets(
    'report test harness preview report generates live reviewed receipt and opens preview',
    (tester) async {
      final fixture = buildReviewedReportGenerationFixture(
        intelligenceEventId: 'INTEL-HARNESS-GENERATE-REVIEWED-1',
        intelligenceId: 'intel-harness-generate-reviewed-1',
      );
      final store = fixture.store;
      final shellState = ValueNotifier(const ReportShellState());
      final previewRequests = <ReportPreviewRequest>[];
      addTearDown(shellState.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ReportShellState>(
            valueListenable: shellState,
            builder: (context, value, _) {
              return ReportTestHarnessPage(
                store: store,
                selectedClient: 'CLIENT-001',
                selectedSite: 'SITE-SANDTON',
                sceneReviewByIntelligenceId:
                    fixture.sceneReviewByIntelligenceId,
                reportShellState: value,
                onReportShellStateChanged: (next) => shellState.value = next,
                onRequestPreview: previewRequests.add,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-harness-kpi-all')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-harness-kpi-reviewed')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-harness-kpi-scene-pending')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );

      final previewReportAction = find.text('Preview Report').first;
      await tester.ensureVisible(previewReportAction);
      await tester.tap(previewReportAction);
      await tester.pumpAndSettle();

      final reportEvents = store
          .allEvents()
          .whereType<ReportGenerated>()
          .toList();
      expect(reportEvents, hasLength(1));

      final generatedReceipt = reportEvents.single;
      expect(previewRequests, hasLength(1));
      expect(
        previewRequests.single.receiptEvent?.eventId,
        generatedReceipt.eventId,
      );
      expect(previewRequests.single.bundle.sceneReview.totalReviews, 1);
      expect(
        previewRequests.single.bundle.sceneReview.highlights.single.summary,
        reportTestSuppressedDecisionSummary,
      );
      expect(shellState.value.selectedReceiptEventId, generatedReceipt.eventId);
      expect(shellState.value.previewReceiptEventId, generatedReceipt.eventId);
      expect(find.text('No ReportGenerated receipts yet.'), findsNothing);
      expect(find.text(generatedReceipt.eventId), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-harness-kpi-all')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-harness-kpi-reviewed')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-harness-kpi-scene-pending')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Preview target: ${generatedReceipt.eventId}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'report test harness preview report opens reviewed preview route without callback',
    (tester) async {
      final fixture = buildReviewedReportGenerationFixture(
        intelligenceEventId: 'INTEL-HARNESS-GENERATE-ROUTE-REVIEWED-1',
        intelligenceId: 'intel-harness-generate-route-reviewed-1',
      );
      final store = fixture.store;

      await tester.pumpWidget(
        MaterialApp(
          home: ReportTestHarnessPage(
            store: store,
            selectedClient: 'CLIENT-001',
            selectedSite: 'SITE-SANDTON',
            sceneReviewByIntelligenceId: fixture.sceneReviewByIntelligenceId,
            reportShellState: const ReportShellState(
              previewSurface: ReportPreviewSurface.route,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final previewReportAction = find.text('Preview Report').first;
      await tester.ensureVisible(previewReportAction);
      await tester.tap(previewReportAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final reportEvents = store
          .allEvents()
          .whereType<ReportGenerated>()
          .toList();
      expect(reportEvents, hasLength(1));
      expect(find.text('Scene Review Brief'), findsOneWidget);
      expect(find.text('Receipt Integrity'), findsOneWidget);
      expect(
        find.textContaining(reportTestSuppressedDecisionSummary),
        findsOneWidget,
      );
      expect(find.textContaining(reportEvents.single.eventId), findsWidgets);

      Navigator.of(tester.element(find.text('Scene Review Brief'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Scene Review Brief'), findsNothing);
      expect(
        find.text('Preview target: ${reportEvents.single.eventId}'),
        findsOneWidget,
      );
      expect(find.text(reportEvents.single.eventId), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-harness-kpi-all')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-harness-kpi-reviewed')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    },
  );
}
