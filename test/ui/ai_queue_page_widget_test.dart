import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
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

  testWidgets('ai queue prioritizes real autonomy plans from scene reviews', (
    tester,
  ) async {
    final events = [
      IntelligenceReceived(
        eventId: 'evt-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 21, 14),
        intelligenceId: 'intel-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-1',
        clientId: 'CLIENT-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        cameraId: 'gate-cam',
        faceMatchId: 'PERSON-44',
        objectLabel: 'person',
        objectConfidence: 0.95,
        headline: 'HIKVISION LINE CROSSING',
        summary: 'Boundary activity detected',
        riskScore: 92,
        snapshotUrl: 'https://edge.example.com/intel-1.jpg',
        canonicalHash: 'hash-1',
      ),
      IntelligenceReceived(
        eventId: 'evt-2',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 21, 13),
        intelligenceId: 'intel-2',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-2',
        clientId: 'CLIENT-SANDTON',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        cameraId: 'lobby-cam',
        objectLabel: 'person',
        objectConfidence: 0.84,
        headline: 'HIKVISION PERIMETER WATCH',
        summary: 'Routine perimeter activity',
        riskScore: 54,
        snapshotUrl: 'https://edge.example.com/intel-2.jpg',
        canonicalHash: 'hash-2',
      ),
    ];
    final reviews = {
      'intel-1': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-1',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'boundary loitering concern',
        decisionLabel: 'Escalation Candidate',
        decisionSummary:
            'Escalated for urgent review because person activity was detected.',
        summary: 'Person visible near the boundary line.',
        reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 15),
      ),
      'intel-2': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-2',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'monitored boundary watch',
        decisionLabel: 'Monitoring Alert',
        decisionSummary: 'Routine perimeter watch remains active.',
        summary: 'Sandton remains under active watch.',
        reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 16),
      ),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: AIQueuePage(
          events: events,
          sceneReviewByIntelligenceId: reviews,
          videoOpsLabel: 'Hikvision',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GLOBAL POSTURE SHIFT'), findsOneWidget);
    expect(find.text('POSTURAL ECHO'), findsOneWidget);
    expect(find.text('AUTO-DISPATCH HOLD'), findsOneWidget);
    expect(find.textContaining('HIKVISION evidence lock'), findsOneWidget);
    expect(find.text('AUTO'), findsWidgets);
  });
}
