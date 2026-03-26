import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
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

    expect(find.text('AI Automation Queue'), findsWidgets);
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

    expect(find.text('AI Automation Queue'), findsWidgets);
    expect(find.text('Queued Actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ai queue shows active automation controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));

    expect(find.text('AI Automation Queue'), findsOneWidget);
    expect(find.text('View Events'), findsOneWidget);
    expect(find.text('AI ENGINE ACTIVE'), findsOneWidget);
    expect(find.text('TOTAL QUEUE'), findsOneWidget);
    expect(find.text('ACTIVE AUTOMATION'), findsOneWidget);
    expect(find.text('PROPOSED ACTION'), findsOneWidget);
    expect(find.text('INTERVENTION WINDOW'), findsOneWidget);
    expect(find.text('CANCEL ACTION'), findsOneWidget);
    expect(find.text('PAUSE'), findsOneWidget);
    expect(find.text('APPROVE NOW'), findsOneWidget);
    expect(find.text('Queued Actions'), findsOneWidget);
  });

  testWidgets('ai queue header view events opens scoped event review', (
    tester,
  ) async {
    List<String>? openedEventIds;
    String? openedSelectedEventId;

    await tester.pumpWidget(
      MaterialApp(
        home: AIQueuePage(
          events: [
            DecisionCreated(
              eventId: 'evt-dispatch-1',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 19, 7, 30),
              dispatchId: 'DISP-100',
              clientId: 'CLIENT-VALLEE',
              regionId: 'REGION-GAUTENG',
              siteId: 'SITE-VALLEE',
            ),
          ],
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai-queue-view-events-button')));
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['evt-dispatch-1']));
    expect(openedSelectedEventId, 'evt-dispatch-1');
  });

  testWidgets('ai queue countdown decrements every second', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));

    expect(find.text('00:27'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('00:26'), findsOneWidget);
  });

  testWidgets(
    'ai queue switches lanes, changes workspace views, and promotes queued work',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ai-queue-workspace-status-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ai-queue-workspace-panel-runbook')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ai-queue-workspace-command-receipt')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('ai-queue-lane-queued')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ai-queue-focus-card-A002')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-queue-workspace-view-policy')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ai-queue-workspace-view-policy')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ai-queue-workspace-panel-policy')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('ai-queue-workspace-view-context')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ai-queue-workspace-panel-context')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('ai-queue-workspace-view-runbook')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-queue-workspace-promote-action')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ai-queue-workspace-promote-action')),
      );
      await tester.pumpAndSettle();

      expect(find.text('PAUSE'), findsOneWidget);
      expect(find.text('Initiate safe-word verification call.'), findsWidgets);
      expect(
        find.text('Promoted INC-8830-RZ into the live window.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      final pauseButton = find.widgetWithText(FilledButton, 'PAUSE');
      await tester.ensureVisible(pauseButton);
      await tester.tap(pauseButton);
      await tester.pumpAndSettle();

      expect(find.text('RESUME'), findsOneWidget);
      expect(find.text('Paused INC-8830-RZ.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'ai queue standby workspace recovers through runbook, policy, and context',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        final cancelActionButton = find.text('CANCEL ACTION').first;
        await tester.ensureVisible(cancelActionButton);
        await tester.tap(cancelActionButton);
        await tester.pumpAndSettle();
      }

      expect(
        find.byKey(const ValueKey('ai-queue-empty-lane-recovery')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ai-queue-focus-standby-recovery')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ai-queue-runbook-standby-recovery')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-queue-runbook-standby-open-policy')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ai-queue-runbook-standby-open-policy')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ai-queue-policy-empty-recovery')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-queue-policy-empty-open-context')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ai-queue-policy-empty-open-context')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ai-queue-context-standby-recovery')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-queue-context-standby-prime-live')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ai-queue-context-standby-prime-live')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ai-queue-runbook-standby-recovery')),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('ai queue cancel action is stable on web', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AIQueuePage(events: [])));
    await tester.pumpAndSettle();

    final cancelActionButton = find.text('CANCEL ACTION').first;
    await tester.ensureVisible(cancelActionButton);
    await tester.tap(cancelActionButton);
    await tester.pumpAndSettle();

    expect(find.text('AI Automation Queue'), findsWidgets);
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
            historicalShadowStrengthLabels: const ['strength rising'],
            previousTomorrowUrgencySummary: 'strength stable • high • 28s',
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
      expect(find.text('URGENCY'), findsOneWidget);
      expect(find.textContaining('strength rising • critical'), findsOneWidget);
      expect(find.text('PREVIOUS URGENCY'), findsOneWidget);
      expect(
        find.textContaining('strength stable • high • 28s'),
        findsOneWidget,
      );

      final biasTopLeft = tester.getTopLeft(find.text('SHADOW READINESS BIAS'));
      final draftTopLeft = tester.getTopLeft(
        find.text('DRAFT NEXT-SHIFT ACCESS HARDENING').first,
      );
      expect(biasTopLeft.dy, lessThan(draftTopLeft.dy));
    },
  );

  testWidgets('ai queue explains posture-heated promotion pressure for synthetic policy', (
    tester,
  ) async {
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
        siteId: 'SITE-SEED',
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
        eventId: 'evt-shadow-live-1',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 21, 14),
        intelligenceId: 'intel-shadow-live-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-shadow-live-1',
        clientId: 'CLIENT-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        cameraId: 'office-cam-1',
        objectLabel: 'person',
        objectConfidence: 0.95,
        headline: 'Unplanned contractor roaming',
        summary:
            'Maintenance-like subject moved across restricted office doors.',
        riskScore: 86,
        snapshotUrl: 'https://edge.example.com/shadow-live-1.jpg',
        canonicalHash: 'hash-shadow-live-1',
      ),
      IntelligenceReceived(
        eventId: 'evt-shadow-live-2',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 21, 18),
        intelligenceId: 'intel-shadow-live-2',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-shadow-live-2',
        clientId: 'CLIENT-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        cameraId: 'office-cam-2',
        objectLabel: 'person',
        objectConfidence: 0.95,
        headline: 'Contractor repeating office sweep',
        summary: 'Maintenance-like subject kept probing multiple office doors.',
        riskScore: 87,
        snapshotUrl: 'https://edge.example.com/shadow-live-2.jpg',
        canonicalHash: 'hash-shadow-live-2',
      ),
      IntelligenceReceived(
        eventId: 'evt-shadow-live-3',
        sequence: 4,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 21, 22),
        intelligenceId: 'intel-shadow-live-3',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-shadow-live-3',
        clientId: 'CLIENT-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        cameraId: 'office-cam-3',
        objectLabel: 'person',
        objectConfidence: 0.95,
        headline: 'Contractor revisits office floors',
        summary:
            'Service-looking subject returned to several restricted office zones.',
        riskScore: 89,
        snapshotUrl: 'https://edge.example.com/shadow-live-3.jpg',
        canonicalHash: 'hash-shadow-live-3',
      ),
      IntelligenceReceived(
        eventId: 'evt-shadow-live-4',
        sequence: 5,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 16, 21, 26),
        intelligenceId: 'intel-shadow-live-4',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-shadow-live-4',
        clientId: 'CLIENT-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-VALLEE',
        cameraId: 'office-cam-4',
        objectLabel: 'person',
        objectConfidence: 0.96,
        headline: 'Contractor returns to office zone again',
        summary:
            'Service-looking subject kept sweeping office floors and retrying access.',
        riskScore: 92,
        snapshotUrl: 'https://edge.example.com/shadow-live-4.jpg',
        canonicalHash: 'hash-shadow-live-4',
      ),
    ];
    final reviews = {
      'intel-shadow-live-1': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-shadow-live-1',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'service impersonation and roaming concern',
        decisionLabel: 'Escalation Candidate',
        decisionSummary: 'Likely spoofed service access with abnormal roaming.',
        summary: 'Likely maintenance impersonation moving across office zones.',
        reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 15),
      ),
      'intel-shadow-live-2': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-shadow-live-2',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'service impersonation and roaming concern',
        decisionLabel: 'Escalation Candidate',
        decisionSummary: 'Likely spoofed service access with abnormal roaming.',
        summary:
            'Likely maintenance impersonation moving across office zones repeatedly.',
        reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 18),
      ),
      'intel-shadow-live-3': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-shadow-live-3',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'service impersonation and roaming concern',
        decisionLabel: 'Escalation Candidate',
        decisionSummary: 'Likely spoofed service access with abnormal roaming.',
        summary:
            'Likely maintenance impersonation moving across office zones again.',
        reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 22),
      ),
      'intel-shadow-live-4': MonitoringSceneReviewRecord(
        intelligenceId: 'intel-shadow-live-4',
        sourceLabel: 'openai:gpt-5.4-mini',
        postureLabel: 'service impersonation and roaming concern',
        decisionLabel: 'Escalation Candidate',
        decisionSummary: 'Likely spoofed service access with abnormal roaming.',
        summary:
            'Likely maintenance impersonation continuing across office zones.',
        reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 26),
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

    expect(find.textContaining('POLICY RECOMMENDATION'), findsOneWidget);
    expect(find.textContaining('Promotion pressure:'), findsOneWidget);
    expect(
      find.textContaining('Promotion execution: high • 40s'),
      findsOneWidget,
    );
    expect(find.textContaining('toward validated review'), findsWidgets);
    expect(find.textContaining('posture POSTURE'), findsWidgets);
    expect(find.text('DRAFT NEXT-SHIFT ACCESS HARDENING'), findsWidgets);

    final policyTopLeft = tester.getTopLeft(
      find.textContaining('POLICY RECOMMENDATION'),
    );
    final draftTopLeft = tester.getTopLeft(
      find.text('DRAFT NEXT-SHIFT ACCESS HARDENING').first,
    );
    expect(policyTopLeft.dy, lessThan(draftTopLeft.dy));
    expect(find.textContaining('Promotion pressure'), findsWidgets);
    expect(find.textContaining('Promotion execution'), findsWidgets);
  });

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
    expect(find.text('POSTURE WEIGHT'), findsOneWidget);
    expect(find.textContaining('weight '), findsWidgets);

    final openDossierButton = find.byKey(
      const ValueKey('ai-queue-mo-shadow-open-dossier'),
    );
    await tester.ensureVisible(openDossierButton);
    await tester.tap(openDossierButton);
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

  testWidgets('ai queue pins shadow dossier copy in the desktop context rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments;
          if (arguments is Map) {
            clipboardText = arguments['text'] as String?;
          }
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ai-queue-workspace-command-receipt')),
      findsOneWidget,
    );

    final openDossierButton = find.byKey(
      const ValueKey('ai-queue-mo-shadow-open-dossier'),
    );
    await tester.ensureVisible(openDossierButton);
    await tester.tap(openDossierButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('COPY JSON'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ai-queue-mo-shadow-dialog')),
      findsNothing,
    );
    expect(clipboardText, contains('SITE-OFFICE'));
    expect(find.text('Shadow MO dossier copied'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
