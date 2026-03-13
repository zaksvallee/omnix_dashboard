import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('administration page stays stable on phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Administration'), findsOneWidget);
    expect(find.text('Administration Console'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administration page stays stable on landscape viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Administration'), findsOneWidget);
    expect(find.text('Employees'), findsOneWidget);
    expect(find.text('Sites'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administration page switches tabs and shows system cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Thabo Mokoena'), findsOneWidget);

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('SLA Tiers'), findsOneWidget);
    expect(find.text('Risk Policies'), findsOneWidget);
    expect(find.text('System Information'), findsOneWidget);
  });

  testWidgets('administration page filters guards by search query', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Nomsa');
    await tester.pumpAndSettle();

    expect(find.textContaining('Nomsa Khumalo'), findsOneWidget);
    expect(find.textContaining('Thabo Mokoena'), findsNothing);
  });

  testWidgets('system tab shows ops poll health rows when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          radioOpsPollHealth: 'ok 3 • fail 1 • skip 0 • last 10:05:00 UTC',
          radioOpsQueueHealth:
              'pending 4 • due 1 • deferred 3 • max-attempt 2 • next 10:05:30 UTC',
          radioOpsQueueIntentMix:
              'pending intent mix • all_clear 2 • panic 1 • duress 1 • status 0 • unknown 0',
          radioOpsAckRecentSummary:
              'recent ack 5 (6h) • all_clear 2 • panic 1 • duress 1 • status 1',
          radioOpsQueueStateDetail: 'Queue updated via ingest • 10:06:20 UTC',
          radioOpsFailureDetail:
              'Last failure • ZEL-9001 • reason send_failed • count 2 • at 10:05:30 UTC',
          radioOpsFailureAuditDetail: 'Failure snapshot cleared • 10:06:00 UTC',
          radioOpsManualActionDetail:
              'Retry requested for 4 queued • 10:05:15 UTC',
          cctvOpsPollHealth: 'ok 2 • fail 0 • skip 0 • last 10:05:01 UTC',
          cctvCapabilitySummary: 'caps LIVE AI MONITORING • FR • LPR',
          cctvRecentSignalSummary:
              'recent video intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 1 • lpr 2',
          cctvEvidenceHealthSummary:
              'verified 2 • fail 0 • dropped 0 • queue 2/12 • last 10:05:01 UTC',
          cctvCameraHealthSummary:
              'front-gate:healthy • zone north_gate • stale 1m | yard:stale • zone driveway • stale 42m',
          wearableOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:02 UTC',
          newsOpsPollHealth: 'ok 4 • fail 0 • skip 0 • last 10:05:03 UTC',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('Ops Integration Poll Health'), findsOneWidget);
    expect(find.textContaining('ok 3 • fail 1'), findsOneWidget);
    expect(
      find.textContaining('pending 4 • due 1 • deferred 3'),
      findsOneWidget,
    );
    expect(
      find.textContaining('pending intent mix • all_clear 2 • panic 1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('recent ack 5 (6h) • all_clear 2 • panic 1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Queue updated via ingest • 10:06:20 UTC'),
      findsOneWidget,
    );
    expect(find.textContaining('Last failure • ZEL-9001'), findsOneWidget);
    expect(
      find.textContaining('Failure snapshot cleared • 10:06:00 UTC'),
      findsOneWidget,
    );
    expect(find.textContaining('Retry requested for 4 queued'), findsOneWidget);
    expect(find.textContaining('ok 2 • fail 0'), findsOneWidget);
    expect(
      find.textContaining('LIVE AI MONITORING • FR • LPR'),
      findsOneWidget,
    );
    expect(
      find.textContaining('recent video intel 5 (6h) • intrusion 2'),
      findsOneWidget,
    );
    expect(
      find.textContaining('verified 2 • fail 0 • dropped 0 • queue 2/12'),
      findsOneWidget,
    );
    expect(
      find.textContaining('front-gate:healthy • zone north_gate'),
      findsOneWidget,
    );
    expect(find.textContaining('ok 1 • fail 0'), findsOneWidget);
    expect(find.textContaining('ok 4 • fail 0'), findsOneWidget);
  });

  testWidgets('system tab validates and saves radio intent dictionary', (
    tester,
  ) async {
    String? savedRaw;
    var resetCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialRadioIntentPhrasesJson:
              '{"all_clear":["all clear"],"panic":["panic"],"duress":["silent duress"],"status":["status update"]}',
          onSaveRadioIntentPhrasesJson: (rawJson) async {
            savedRaw = rawJson;
          },
          onResetRadioIntentPhrasesJson: () async {
            resetCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('Radio Intent Dictionary'), findsOneWidget);
    final radioEditor = find.byWidgetPredicate((widget) {
      if (widget is! TextField) return false;
      final hint = widget.decoration?.hintText ?? '';
      return hint.contains('"panic button"');
    });
    final radioValidateButton = find.text('Validate').first;
    final radioSaveButton = find.text('Save Runtime').first;
    final radioResetButton = find.text('Reset To Defaults').first;
    expect(radioEditor, findsOneWidget);
    expect(radioValidateButton, findsOneWidget);
    expect(radioSaveButton, findsOneWidget);
    expect(radioResetButton, findsOneWidget);

    await tester.enterText(radioEditor, '{not-json');
    await tester.ensureVisible(radioValidateButton);
    await tester.pumpAndSettle();
    await tester.tap(radioValidateButton);
    await tester.pumpAndSettle();
    expect(savedRaw, isNull);

    await tester.enterText(
      radioEditor,
      '{"all_clear":["all clear"],"panic":["panic button"],"duress":["duress"],"status":["status check"]}',
    );
    await tester.ensureVisible(radioSaveButton);
    await tester.pumpAndSettle();
    await tester.tap(radioSaveButton);
    await tester.pumpAndSettle();

    expect(savedRaw, contains('"panic button"'));

    await tester.ensureVisible(radioResetButton);
    await tester.pumpAndSettle();
    await tester.tap(radioResetButton);
    await tester.pumpAndSettle();
    expect(resetCalls, 1);
  });

  testWidgets('system tab invokes radio queue action callbacks', (
    tester,
  ) async {
    var runOpsPollCalls = 0;
    var runRadioPollCalls = 0;
    var runCctvPollCalls = 0;
    var runWearablePollCalls = 0;
    var runNewsPollCalls = 0;
    var retryCalls = 0;
    var clearCalls = 0;
    var clearFailureSnapshotCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          videoOpsLabel: 'DVR',
          radioOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:00 UTC',
          radioOpsQueueHealth: 'pending 2 • due 1 • deferred 1 • max-attempt 2',
          radioOpsFailureDetail:
              'Last failure • ZEL-9001 • reason send_failed • count 2 • at 10:05:30 UTC',
          radioQueueHasPending: true,
          onRunOpsIntegrationPoll: () async {
            runOpsPollCalls += 1;
          },
          onRunRadioPoll: () async {
            runRadioPollCalls += 1;
          },
          onRunCctvPoll: () async {
            runCctvPollCalls += 1;
          },
          onRunWearablePoll: () async {
            runWearablePollCalls += 1;
          },
          onRunNewsPoll: () async {
            runNewsPollCalls += 1;
          },
          onRetryRadioQueue: () async {
            retryCalls += 1;
          },
          onClearRadioQueue: () async {
            clearCalls += 1;
          },
          onClearRadioQueueFailureSnapshot: () async {
            clearFailureSnapshotCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Run Ops Poll Now').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run Ops Poll Now').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Poll Radio').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll Radio').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Poll DVR').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll DVR').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Poll Wearable').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll Wearable').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Poll News').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll News').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry Radio Queue').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry Radio Queue').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear Radio Queue').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Radio Queue').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Radio Queue?'), findsOneWidget);
    await tester.tap(find.text('Confirm Clear').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear Last Failure').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Last Failure').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Last Failure Snapshot?'), findsOneWidget);
    await tester.tap(find.text('Confirm Clear').first);
    await tester.pumpAndSettle();

    expect(runOpsPollCalls, 1);
    expect(runRadioPollCalls, 1);
    expect(runCctvPollCalls, 1);
    expect(runWearablePollCalls, 1);
    expect(runNewsPollCalls, 1);
    expect(retryCalls, 1);
    expect(clearCalls, 1);
    expect(clearFailureSnapshotCalls, 1);
  });

  testWidgets('system tab clear radio queue cancel does not invoke callback', (
    tester,
  ) async {
    var clearCalls = 0;
    var clearFailureSnapshotCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          radioOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:00 UTC',
          radioOpsQueueHealth: 'pending 1 • due 1 • deferred 0 • max-attempt 1',
          radioOpsFailureDetail:
              'Last failure • ZEL-9001 • reason send_failed • count 1 • at 10:05:30 UTC',
          radioQueueHasPending: true,
          onClearRadioQueue: () async {
            clearCalls += 1;
          },
          onClearRadioQueueFailureSnapshot: () async {
            clearFailureSnapshotCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Clear Radio Queue').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Radio Queue').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Radio Queue?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear Last Failure').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Last Failure').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Last Failure Snapshot?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    expect(clearCalls, 0);
    expect(clearFailureSnapshotCalls, 0);
  });

}
