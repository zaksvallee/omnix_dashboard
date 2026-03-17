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
    await tester.pump(const Duration(milliseconds: 100));
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
          historicalSyntheticLearningLabels: const ['ADVANCE FIRE'],
          sceneReviewByIntelligenceId: reviews,
          videoOpsLabel: 'Hikvision',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('GLOBAL POSTURE SHIFT'), findsOneWidget);
    expect(find.text('SYNTHETIC WAR-ROOM'), findsOneWidget);
    expect(find.text('POSTURAL ECHO'), findsOneWidget);
    expect(find.text('AUTO-DISPATCH HOLD'), findsOneWidget);
    expect(find.textContaining('HIKVISION evidence lock'), findsOneWidget);
    expect(
      find.textContaining('Replay the next-shift posture'),
      findsOneWidget,
    );
    expect(find.text('AUTO'), findsWidgets);
  });

  testWidgets('ai queue surfaces fire escalation plans from hazard posture', (
    tester,
  ) async {
    final events = [
      IntelligenceReceived(
        eventId: 'evt-fire',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 21, 14),
        intelligenceId: 'intel-fire',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-fire',
        clientId: 'CLIENT-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-FIRE',
        cameraId: 'generator-room-cam',
        objectLabel: 'smoke',
        objectConfidence: 0.96,
        headline: 'HIKVISION FIRE ALERT',
        summary: 'Smoke detected near the generator room.',
        riskScore: 78,
        snapshotUrl: 'https://edge.example.com/fire.jpg',
        canonicalHash: 'hash-fire',
      ),
    ];
    final reviews = {
      'intel-fire': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-fire',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'fire and smoke emergency',
        decisionLabel: 'Escalation Candidate',
        decisionSummary:
            'Escalated for urgent review because fire or smoke indicators were detected.',
        summary: 'Smoke plume visible in the generator room.',
        reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 15),
      ),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: AIQueuePage(
          events: events,
          historicalSyntheticLearningLabels: const ['ADVANCE FIRE'],
          sceneReviewByIntelligenceId: reviews,
          videoOpsLabel: 'Hikvision',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('FIRE ESCALATION'), findsOneWidget);
    expect(find.text('DISPATCH FIRE RESPONSE'), findsOneWidget);
    expect(find.text('TRIGGER OCCUPANT WELFARE CHECK'), findsOneWidget);
    expect(
      find.textContaining('Promote immediate fire response'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Stage fire response for SITE-FIRE'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Trigger immediate occupant welfare verification'),
      findsOneWidget,
    );
    expect(find.textContaining('HIKVISION evidence'), findsOneWidget);
  });

  testWidgets(
    'ai queue prioritizes shadow readiness bias from repeated MO memory',
    (tester) async {
      final events = [
        IntelligenceReceived(
          eventId: 'evt-shadow-news',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 16, 20, 50),
          intelligenceId: 'intel-shadow-news',
          provider: 'news_feed_monitor',
          sourceType: 'news',
          externalId: 'ext-shadow-news',
          clientId: 'CLIENT-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-OFFICE',
          cameraId: 'feed-news',
          objectLabel: 'person',
          objectConfidence: 0.70,
          headline: 'Contractors moved floor to floor in office park',
          summary:
              'Suspects posed as maintenance contractors before moving across restricted office zones.',
          riskScore: 67,
          snapshotUrl: 'https://edge.example.com/shadow-news.jpg',
          canonicalHash: 'hash-shadow-news',
        ),
        IntelligenceReceived(
          eventId: 'evt-shadow-live',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 16, 21, 14),
          intelligenceId: 'intel-shadow-live',
          provider: 'hikvision_dvr_monitor_only',
          sourceType: 'dvr',
          externalId: 'ext-shadow-live',
          clientId: 'CLIENT-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-OFFICE',
          cameraId: 'lobby-cam',
          objectLabel: 'person',
          objectConfidence: 0.95,
          headline: 'Unplanned contractor roaming',
          summary:
              'Maintenance-like subject moved across restricted office doors.',
          riskScore: 91,
          snapshotUrl: 'https://edge.example.com/shadow-live.jpg',
          canonicalHash: 'hash-shadow-live',
        ),
      ];
      final reviews = {
        'intel-shadow-live': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-shadow-live',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'service impersonation and roaming concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Likely spoofed service access with abnormal roaming.',
          summary:
              'Likely maintenance impersonation moving across office zones.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 15),
        ),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: AIQueuePage(
            events: events,
            historicalShadowMoLabels: const ['HARDEN ACCESS'],
            sceneReviewByIntelligenceId: reviews,
            videoOpsLabel: 'Hikvision',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SHADOW READINESS BIAS'), findsOneWidget);
      expect(find.text('DRAFT NEXT-SHIFT ACCESS HARDENING'), findsWidgets);
      expect(find.text('SHADOW'), findsOneWidget);
      expect(find.textContaining('HARDEN ACCESS'), findsWidgets);

      final biasTopLeft = tester.getTopLeft(find.text('SHADOW READINESS BIAS'));
      final draftTopLeft = tester.getTopLeft(
        find.text('DRAFT NEXT-SHIFT ACCESS HARDENING').first,
      );
      expect(biasTopLeft.dy, lessThan(draftTopLeft.dy));
    },
  );

  testWidgets('ai queue surfaces shadow MO intelligence from external patterns', (
    tester,
  ) async {
    List<String>? openedEventIds;
    String? openedSelectedEventId;
    final events = [
      IntelligenceReceived(
        eventId: 'evt-news',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 20, 0),
        intelligenceId: 'intel-news',
        provider: 'security_bulletin',
        sourceType: 'news',
        externalId: 'news-1',
        clientId: 'CLIENT-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-OFFICE',
        cameraId: 'feed-news',
        objectLabel: 'person',
        objectConfidence: 0.7,
        headline: 'Contractors moved floor to floor in office park',
        summary:
            'Suspects posed as maintenance contractors, moved floor to floor through a business park, and tried several restricted office doors before stealing devices.',
        riskScore: 75,
        snapshotUrl: 'https://edge.example.com/news-office.jpg',
        canonicalHash: 'hash-news-office',
      ),
      IntelligenceReceived(
        eventId: 'evt-office',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 21, 14),
        intelligenceId: 'intel-office',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-office',
        clientId: 'CLIENT-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-OFFICE',
        cameraId: 'office-cam',
        objectLabel: 'person',
        objectConfidence: 0.95,
        headline: 'Maintenance contractor probing office doors',
        summary:
            'Contractor-like person moved floor to floor and tried several restricted office doors.',
        riskScore: 86,
        snapshotUrl: 'https://edge.example.com/office.jpg',
        canonicalHash: 'hash-office',
      ),
    ];
    final reviews = {
      'intel-office': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-office',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'service impersonation and roaming concern',
        decisionLabel: 'Escalation Candidate',
        decisionSummary: 'Likely spoofed service access with abnormal roaming.',
        summary: 'Likely maintenance impersonation moving across office zones.',
        reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 15),
      ),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: AIQueuePage(
          events: events,
          sceneReviewByIntelligenceId: reviews,
          videoOpsLabel: 'Hikvision',
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ai-queue-mo-shadow-card')),
      findsOneWidget,
    );
    expect(find.text('Shadow MO Intelligence'), findsOneWidget);
    expect(
      find.textContaining(
        'SITE-OFFICE • Contractors moved floor to floor in office park',
      ),
      findsOneWidget,
    );
    expect(find.text('mo_shadow'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('ai-queue-mo-shadow-open-dossier')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ai-queue-mo-shadow-dialog')),
      findsOneWidget,
    );
    expect(find.text('SHADOW MO DOSSIER'), findsOneWidget);
    expect(
      find.text('Contractors moved floor to floor in office park'),
      findsWidgets,
    );
    expect(
      find.textContaining('Actions RAISE READINESS • PREPOSITION RESPONSE'),
      findsWidgets,
    );
    expect(find.textContaining('Strength'), findsWidgets);

    await tester.tap(find.text('OPEN EVIDENCE').last);
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['evt-office']));
    expect(openedSelectedEventId, 'evt-office');
  });
}
