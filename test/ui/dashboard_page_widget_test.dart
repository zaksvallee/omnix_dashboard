import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/guard/guard_ops_event.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/ui/dashboard_page.dart';

void main() {
  testWidgets('dashboard guard sync card shows alert badges and opens guard sync', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var openCount = 0;
    var clearPolicyCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: InMemoryEventStore(),
          guardSyncBackendEnabled: false,
          guardSyncInFlight: false,
          guardSyncQueueDepth: 60,
          guardPendingEvents: 5,
          guardPendingMedia: 2,
          guardFailedEvents: 3,
          guardFailedMedia: 1,
          guardOutcomePolicyDeniedCount: 4,
          guardOutcomePolicyDeniedLastReason:
              'Confirmation role "control" is not allowed for true_threat.',
          guardOutcomePolicyDenied24h: 3,
          guardOutcomePolicyDenied7d: 6,
          guardOutcomePolicyDeniedHistoryUtc: [
            DateTime.now().toUtc().subtract(const Duration(hours: 2)),
            DateTime.now().toUtc().subtract(const Duration(days: 2)),
          ],
          guardCoachingAckCount: 5,
          guardCoachingSnoozeCount: 2,
          guardCoachingSnoozeExpiryCount: 1,
          guardCoachingRecentHistory: const [
            '[2026-03-05T12:10:00.000Z] high_failure_backlog acknowledged @ sync by guard',
            '[2026-03-05T12:20:00.000Z] high_failure_backlog snoozed 10m @ dispatch by supervisor',
          ],
          guardLastSuccessfulSyncAtUtc: DateTime.now().toUtc().subtract(
            const Duration(minutes: 20),
          ),
          guardLastFailureReason: 'network unavailable',
          guardRecentEvents: [
            GuardOpsEvent(
              eventId: 'EVT-1',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.panicTriggered,
              sequence: 44,
              occurredAt: DateTime.now().toUtc(),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {},
              failureReason: 'event sync timeout',
            ),
          ],
          guardRecentMedia: [
            GuardOpsMediaUpload(
              mediaId: 'MEDIA-1',
              eventId: 'EVT-1',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              bucket: 'guard-incident-media',
              path: 'guards/GUARD-001/incident/evidence.jpg',
              localPath: '/tmp/evidence.jpg',
              capturedAt: DateTime.now().toUtc(),
              status: GuardMediaUploadStatus.failed,
              failureReason: 'upload timeout',
            ),
          ],
          onOpenGuardSync: () {
            openCount += 1;
          },
          onClearGuardOutcomePolicyTelemetry: () {
            clearPolicyCount += 1;
          },
          guardFailureAlertThreshold: 1,
          guardQueuePressureAlertThreshold: 25,
          guardStaleSyncAlertMinutes: 10,
        ),
      ),
    );

    expect(find.text('Guard Sync Health'), findsOneWidget);
    expect(find.text('Failures'), findsOneWidget);
    expect(find.text('Queue Pressure'), findsOneWidget);
    expect(find.text('Stale Sync'), findsOneWidget);
    expect(find.text('Local Only'), findsOneWidget);
    expect(find.text('Policy Denied'), findsOneWidget);
    expect(find.text('Diagnostics and coaching telemetry'), findsOneWidget);
    await tester.ensureVisible(find.text('Diagnostics and coaching telemetry'));
    await tester.tap(find.text('Diagnostics and coaching telemetry'));
    await tester.pumpAndSettle();
    expect(find.text('Policy denied'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Denied (24h)'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Denied (7d)'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Coaching Ack'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Coaching Snooze'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Snooze Expiry'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Recent Coaching Telemetry'), findsOneWidget);
    expect(find.textContaining('acknowledged @ sync by guard'), findsOneWidget);
    expect(find.textContaining('Policy denied (latest):'), findsOneWidget);
    expect(find.text('Advanced export and share'), findsOneWidget);
    await tester.ensureVisible(find.text('Advanced export and share'));
    await tester.tap(find.text('Advanced export and share'));
    await tester.pumpAndSettle();
    expect(find.text('Copy Policy Telemetry JSON'), findsOneWidget);
    expect(find.text('Copy Policy Telemetry CSV'), findsOneWidget);
    expect(find.text('Download Policy JSON'), findsOneWidget);
    expect(find.text('Download Policy CSV'), findsOneWidget);
    expect(find.text('Share Policy Pack'), findsOneWidget);
    expect(find.text('Copy Coaching Telemetry JSON'), findsOneWidget);
    expect(find.text('Copy Coaching Telemetry CSV'), findsOneWidget);
    expect(find.text('Download Coaching JSON'), findsOneWidget);
    expect(find.text('Share Coaching Pack'), findsOneWidget);
    expect(find.text('Recent Failure Trace'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(
      find.textContaining('Event panicTriggered seq 44: event sync timeout'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Media guard-incident-media: upload timeout'),
      findsOneWidget,
    );
    expect(find.text('Copy Failure Trace'), findsOneWidget);
    expect(find.text('Download Failure Trace'), findsOneWidget);
    expect(find.text('Share Failure Trace'), findsOneWidget);
    expect(find.text('Email Failure Trace'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Guard Sync'));
    await tester.tap(find.text('Open Guard Sync'));
    await tester.pumpAndSettle();
    expect(openCount, 1);
    await tester.tap(find.text('Copy Policy Telemetry JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy Policy Telemetry CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download Policy JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download Policy CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share Policy Pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy Coaching Telemetry JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy Coaching Telemetry CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download Coaching JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share Coaching Pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download Failure Trace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share Failure Trace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email Failure Trace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Policy Telemetry'));
    await tester.pumpAndSettle();
    expect(clearPolicyCount, 1);
  });

  testWidgets('dashboard guard sync card respects alert thresholds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: InMemoryEventStore(),
          guardSyncBackendEnabled: true,
          guardSyncInFlight: false,
          guardSyncQueueDepth: 24,
          guardPendingEvents: 1,
          guardPendingMedia: 0,
          guardFailedEvents: 1,
          guardFailedMedia: 0,
          guardLastSuccessfulSyncAtUtc: DateTime.now().toUtc().subtract(
            const Duration(minutes: 9),
          ),
          guardFailureAlertThreshold: 2,
          guardQueuePressureAlertThreshold: 25,
          guardStaleSyncAlertMinutes: 10,
        ),
      ),
    );

    expect(find.text('Guard Sync Health'), findsOneWidget);
    expect(find.text('Failures'), findsNothing);
    expect(find.text('Queue Pressure'), findsNothing);
    expect(find.text('Stale Sync'), findsNothing);
    expect(find.text('Local Only'), findsNothing);
  });

  testWidgets('dashboard shows triage posture summary', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      IntelligenceReceived(
        eventId: 'E-INT-1',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 12, 0),
        intelligenceId: 'INT-1',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'article-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Armed suspects near gate B',
        summary: 'Vehicle and suspect activity near perimeter gate',
        riskScore: 84,
        canonicalHash: 'hash-1',
      ),
    );
    store.append(
      IntelligenceReceived(
        eventId: 'E-INT-2',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 12, 2),
        intelligenceId: 'INT-2',
        provider: 'community-feed',
        sourceType: 'community',
        externalId: 'community-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Community confirms suspects near gate B',
        summary: 'Repeat suspicious vehicle and armed suspects at perimeter',
        riskScore: 72,
        canonicalHash: 'hash-2',
      ),
    );
    store.append(
      DecisionCreated(
        eventId: 'DEC-1',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 12, 5),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: store,
        ),
      ),
    );

    expect(
      find.text('A 0 • W 1 • DC 1 • Esc 1'),
      findsOneWidget,
    );
    expect(find.textContaining('Top triage signals:'), findsOneWidget);
  });
}
