import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/onyx_agent_context_snapshot_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/incident_closed.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';

void main() {
  const service = LocalOnyxAgentContextSnapshotService();

  test('returns an empty snapshot when no scoped events are loaded', () {
    final snapshot = service.capture(
      events: const <DispatchEvent>[],
      clientId: 'CLIENT-001',
      siteId: 'SITE-SANDTON',
      incidentReference: 'INC-42',
      sourceRouteLabel: 'Command',
    );

    expect(snapshot.scopeLabel, 'CLIENT-001 • SITE-SANDTON');
    expect(snapshot.totalScopedEvents, 0);
    expect(snapshot.activeDispatchCount, 0);
    expect(
      snapshot.toReasoningSummary(),
      contains('No scoped operational events are loaded yet.'),
    );
  });

  test(
    'captures scoped dispatch, field, and visual context for the active incident',
    () {
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-42',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        DecisionCreated(
          eventId: 'evt-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 1),
          dispatchId: 'INC-OTHER',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        IntelligenceReceived(
          eventId: 'evt-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 2),
          intelligenceId: 'intel-1',
          provider: 'vision',
          sourceType: 'cctv',
          externalId: 'vision-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          cameraId: 'CAM-7',
          headline: 'Suspicious vehicle circling gate',
          summary: 'Sedan made multiple slow passes by the east gate.',
          riskScore: 87,
          canonicalHash: 'hash-1',
        ),
        ResponseArrived(
          eventId: 'evt-4',
          sequence: 4,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-42',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        PatrolCompleted(
          eventId: 'evt-5',
          sequence: 5,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
          guardId: 'GUARD-9',
          routeId: 'ROUTE-ALPHA',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          durationSeconds: 840,
        ),
      ];

      final snapshot = service.capture(
        events: events,
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        incidentReference: 'INC-42',
        sourceRouteLabel: 'Track',
      );

      expect(snapshot.totalScopedEvents, 4);
      expect(snapshot.activeDispatchCount, 1);
      expect(snapshot.dispatchesAwaitingResponseCount, 0);
      expect(snapshot.responseCount, 1);
      expect(snapshot.patrolCount, 1);
      expect(snapshot.hasVisualSignal, isTrue);
      expect(
        snapshot.latestIntelligenceHeadline,
        'Suspicious vehicle circling gate',
      );
      expect(snapshot.latestIntelligenceRiskScore, 87);
      expect(snapshot.latestResponderLabel, 'GUARD-9');
      expect(snapshot.latestEventLabel, 'Patrol completed');
      expect(
        snapshot.toReasoningSummary(),
        contains(
          'Latest visual signal: Suspicious vehicle circling gate (risk 87).',
        ),
      );
      expect(snapshot.latestDispatchCreatedAt, DateTime.utc(2026, 3, 31, 8, 0));
    },
  );

  test(
    'surfaces the highest-priority site when multiple sites are in scope',
    () {
      final events = <DispatchEvent>[
        IntelligenceReceived(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          intelligenceId: 'intel-1',
          provider: 'vision',
          sourceType: 'cctv',
          externalId: 'vision-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-A',
          cameraId: 'CAM-1',
          headline: 'Tree motion near the outer fence',
          summary: 'Low-risk movement matched previous wind noise.',
          riskScore: 19,
          canonicalHash: 'hash-1',
        ),
        DecisionCreated(
          eventId: 'evt-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 1),
          dispatchId: 'INC-900',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-B',
        ),
        IntelligenceReceived(
          eventId: 'evt-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 2),
          intelligenceId: 'intel-2',
          provider: 'vision',
          sourceType: 'cctv',
          externalId: 'vision-2',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-B',
          cameraId: 'CAM-9',
          headline: 'Confirmed breach at the north gate',
          summary:
              'Two intruders crossed the perimeter and dispatch is staging.',
          riskScore: 96,
          canonicalHash: 'hash-2',
        ),
      ];

      final snapshot = service.capture(
        events: events,
        clientId: 'CLIENT-001',
        sourceRouteLabel: 'Command',
      );

      expect(snapshot.scopedSiteCount, 2);
      expect(snapshot.prioritySiteLabel, 'SITE-B');
      expect(snapshot.prioritySiteRiskScore, 96);
      expect(snapshot.rankedSiteSummaries, hasLength(2));
      expect(snapshot.rankedSiteSummaries.first, contains('SITE-B'));
      expect(
        snapshot.prioritySiteReason,
        contains('Confirmed breach at the north gate'),
      );
      expect(
        snapshot.toReasoningSummary(),
        contains('Highest-priority site: SITE-B'),
      );
    },
  );

  test(
    'detects guard welfare telemetry and closure timing from scoped events',
    () {
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-42',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        IntelligenceReceived(
          eventId: 'evt-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 2),
          intelligenceId: 'intel-2',
          provider: 'wearable',
          sourceType: 'wearable telemetry',
          externalId: 'wearable-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          headline: 'Guard distress pattern from wearable telemetry',
          summary: 'No movement plus heart rate spike for Guard 9.',
          riskScore: 91,
          canonicalHash: 'hash-2',
        ),
        IncidentClosed(
          eventId: 'evt-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-42',
          resolutionType: 'all_clear',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
      ];

      final snapshot = service.capture(
        events: events,
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        incidentReference: 'INC-42',
        sourceRouteLabel: 'Track',
      );

      expect(snapshot.hasHumanSafetySignal, isTrue);
      expect(snapshot.hasGuardWelfareRisk, isTrue);
      expect(
        snapshot.guardWelfareSignalLabel,
        'Guard distress pattern from wearable telemetry',
      );
      expect(snapshot.latestClosureAt, DateTime.utc(2026, 3, 31, 8, 4));
      expect(
        snapshot.toReasoningSummary(),
        contains(
          'Guard welfare signal: Guard distress pattern from wearable telemetry.',
        ),
      );
    },
  );
}
