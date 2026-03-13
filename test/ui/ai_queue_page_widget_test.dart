import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/ui/ai_queue_page.dart';

void main() {
  testWidgets('ai queue stays stable on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));
    await tester.pumpAndSettle();

    expect(find.text('AI Automation Queue'), findsOneWidget);
    expect(find.text('Queued Actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ai queue stays stable on landscape phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));
    await tester.pumpAndSettle();

    expect(find.text('AI Automation Queue'), findsOneWidget);
    expect(find.text('Queued Actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ai queue shows active automation controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));

    expect(find.text('AI Automation Queue'), findsOneWidget);
    expect(find.text('Active Automation'), findsOneWidget);
    expect(find.text('CANCEL ACTION'), findsOneWidget);
    expect(find.text('PAUSE'), findsOneWidget);
    expect(find.text('APPROVE NOW'), findsOneWidget);
    expect(find.text('Queued Actions'), findsOneWidget);
  });

  testWidgets('ai queue countdown decrements every second', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));

    expect(find.text('00:27'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('00:26'), findsOneWidget);
  });

  testWidgets('ai queue cancel action is stable on web', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CANCEL ACTION').first);
    await tester.pumpAndSettle();

    expect(find.text('AI Automation Queue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ai queue switches video activation labels for DVR', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AIQueuePage(events: [], videoOpsLabel: 'DVR'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DVR ACTIVATION'), findsOneWidget);
    expect(
      find.textContaining('Request DVR stream from perimeter cameras.'),
      findsOneWidget,
    );
  });
}
