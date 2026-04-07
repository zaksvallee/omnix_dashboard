import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/execution_completed.dart';
import 'package:omnix_dashboard/domain/events/execution_denied.dart';
import 'package:omnix_dashboard/domain/events/guard_checked_in.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/domain/projection/operations_health_projection.dart';

DateTime _opsTime(int minute) => DateTime.utc(2026, 4, 7, 8, minute);

DecisionCreated _opsDecision(
  String dispatchId,
  int sequence, {
  String clientId = 'CLIENT-1',
  String regionId = 'REGION-1',
  String siteId = 'SITE-1',
}) {
  return DecisionCreated(
    eventId: 'decision-$dispatchId-$sequence',
    sequence: sequence,
    version: 1,
    occurredAt: _opsTime(sequence),
    dispatchId: dispatchId,
    clientId: clientId,
    regionId: regionId,
    siteId: siteId,
  );
}

ExecutionCompleted _opsExecution(
  String dispatchId,
  int sequence, {
  required bool success,
  String clientId = 'CLIENT-1',
  String regionId = 'REGION-1',
  String siteId = 'SITE-1',
}) {
  return ExecutionCompleted(
    eventId: 'execution-$dispatchId-$sequence',
    sequence: sequence,
    version: 1,
    occurredAt: _opsTime(sequence),
    dispatchId: dispatchId,
    clientId: clientId,
    regionId: regionId,
    siteId: siteId,
    success: success,
  );
}

ExecutionDenied _opsDenied(
  String dispatchId,
  int sequence, {
  String clientId = 'CLIENT-1',
  String regionId = 'REGION-1',
  String siteId = 'SITE-1',
}) {
  return ExecutionDenied(
    eventId: 'denied-$dispatchId-$sequence',
    sequence: sequence,
    version: 1,
    occurredAt: _opsTime(sequence),
    dispatchId: dispatchId,
    clientId: clientId,
    regionId: regionId,
    siteId: siteId,
    operatorId: 'OP-1',
    reason: 'No coverage',
  );
}

GuardCheckedIn _opsCheckIn(
  String guardId,
  int sequence, {
  String clientId = 'CLIENT-1',
  String regionId = 'REGION-1',
  String siteId = 'SITE-1',
}) {
  return GuardCheckedIn(
    eventId: 'checkin-$guardId-$sequence',
    sequence: sequence,
    version: 1,
    occurredAt: _opsTime(sequence),
    guardId: guardId,
    clientId: clientId,
    regionId: regionId,
    siteId: siteId,
  );
}

PatrolCompleted _opsPatrol(
  String routeId,
  int sequence, {
  String clientId = 'CLIENT-1',
  String regionId = 'REGION-1',
  String siteId = 'SITE-1',
}) {
  return PatrolCompleted(
    eventId: 'patrol-$routeId-$sequence',
    sequence: sequence,
    version: 1,
    occurredAt: _opsTime(sequence),
    guardId: 'GUARD-1',
    routeId: routeId,
    clientId: clientId,
    regionId: regionId,
    siteId: siteId,
    durationSeconds: 900,
  );
}

IntelligenceReceived _opsIntel(
  int sequence, {
  required int riskScore,
  String clientId = 'CLIENT-1',
  String regionId = 'REGION-1',
  String siteId = 'SITE-1',
}) {
  return IntelligenceReceived(
    eventId: 'intel-$sequence',
    sequence: sequence,
    version: 1,
    occurredAt: _opsTime(sequence),
    intelligenceId: 'INTEL-$sequence',
    provider: 'provider-$sequence',
    sourceType: 'camera',
    externalId: 'EXT-$sequence',
    clientId: clientId,
    regionId: regionId,
    siteId: siteId,
    headline: 'Intel $sequence',
    summary: 'Summary $sequence',
    riskScore: riskScore,
    canonicalHash: 'hash-$sequence',
  );
}

ResponseArrived _opsResponse(
  String dispatchId,
  int sequence, {
  int responseMinute = 0,
  String clientId = 'CLIENT-1',
  String regionId = 'REGION-1',
  String siteId = 'SITE-1',
}) {
  return ResponseArrived(
    eventId: 'response-$dispatchId-$sequence',
    sequence: sequence,
    version: 1,
    occurredAt: _opsTime(responseMinute),
    dispatchId: dispatchId,
    guardId: 'GUARD-1',
    clientId: clientId,
    regionId: regionId,
    siteId: siteId,
  );
}

void main() {
  group('OperationsHealthProjection.build', () {
    test('returns zero-state snapshot for an empty event list', () {
      final snapshot = OperationsHealthProjection.build(const <DispatchEvent>[]);

      expect(snapshot.totalSites, 0);
      expect(snapshot.totalDecisions, 0);
      expect(snapshot.totalExecuted, 0);
      expect(snapshot.totalDenied, 0);
      expect(snapshot.totalFailed, 0);
      expect(snapshot.totalCheckIns, 0);
      expect(snapshot.totalPatrols, 0);
      expect(snapshot.averageResponseMinutes, 0.0);
      expect(snapshot.controllerPressureIndex, 0.0);
      expect(snapshot.totalIntelligenceReceived, 0);
      expect(snapshot.highRiskIntelligence, 0);
      expect(snapshot.liveSignals, isEmpty);
      expect(snapshot.dispatchFeed, isEmpty);
      expect(
        snapshot.lastEventAtUtc,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    });

    test('counts core event totals and high-risk intelligence threshold', () {
      final events = <DispatchEvent>[
        _opsDecision('D-1', 1),
        _opsExecution('D-1', 2, success: true),
        _opsDecision('D-2', 3),
        _opsDenied('D-2', 4),
        _opsExecution('D-3', 5, success: false),
        _opsCheckIn('GUARD-1', 6),
        _opsPatrol('ROUTE-1', 7),
        _opsIntel(8, riskScore: 69),
        _opsIntel(9, riskScore: 70),
      ];

      final snapshot = OperationsHealthProjection.build(events);

      expect(snapshot.totalDecisions, 2);
      expect(snapshot.totalExecuted, 1);
      expect(snapshot.totalDenied, 1);
      expect(snapshot.totalFailed, 1);
      expect(snapshot.totalCheckIns, 1);
      expect(snapshot.totalPatrols, 1);
      expect(snapshot.totalIntelligenceReceived, 2);
      expect(snapshot.highRiskIntelligence, 1);
      expect(snapshot.lastEventAtUtc, _opsTime(9));
    });

    test('computes average response minutes and skips unmatched responses', () {
      final events = <DispatchEvent>[
        _opsDecision('D-1', 1),
        _opsResponse('D-1', 2, responseMinute: 7),
        _opsResponse('D-UNMATCHED', 3, responseMinute: 9),
      ];

      final snapshot = OperationsHealthProjection.build(events);
      final site = snapshot.sites.single;

      expect(snapshot.averageResponseMinutes, closeTo(6.0, 0.001));
      expect(site.averageResponseMinutes, closeTo(6.0, 0.001));
    });

    test('derives strong and critical health statuses from site activity', () {
      final events = <DispatchEvent>[
        _opsDecision('A-1', 1, siteId: 'SITE-A'),
        _opsExecution('A-1', 2, success: true, siteId: 'SITE-A'),
        for (var i = 0; i < 10; i++) ...[
          _opsCheckIn('GUARD-A-$i', 10 + i, siteId: 'SITE-A'),
          _opsPatrol('ROUTE-A-$i', 30 + i, siteId: 'SITE-A'),
        ],
        for (var i = 0; i < 5; i++) ...[
          _opsDecision('B-$i', 60 + (i * 2), siteId: 'SITE-B'),
          _opsExecution(
            'B-$i',
            61 + (i * 2),
            success: false,
            siteId: 'SITE-B',
          ),
        ],
      ];

      final snapshot = OperationsHealthProjection.build(events);
      final strongSite = snapshot.sites.firstWhere((site) => site.siteId == 'SITE-A');
      final criticalSite = snapshot.sites.firstWhere(
        (site) => site.siteId == 'SITE-B',
      );

      expect(strongSite.healthStatus, 'STRONG');
      expect(strongSite.healthScore, 100.0);
      expect(criticalSite.healthStatus, 'CRITICAL');
      expect(criticalSite.healthScore, 40.0);
    });

    test('computes controller pressure and truncates live signals and dispatch feed', () {
      final pressureEvents = <DispatchEvent>[
        _opsDecision('P-1', 1),
        _opsDecision('P-2', 2),
        _opsDecision('P-3', 3),
        _opsExecution('P-3', 4, success: false),
      ];
      final pressureSnapshot = OperationsHealthProjection.build(pressureEvents);

      expect(pressureSnapshot.controllerPressureIndex, 40.0);

      final truncationEvents = <DispatchEvent>[
        for (var i = 0; i < 10; i++) _opsCheckIn('GUARD-$i', i + 1),
        for (var i = 0; i < 10; i++) _opsDecision('D-$i', 20 + i),
      ];
      final truncationSnapshot = OperationsHealthProjection.build(truncationEvents);

      expect(truncationSnapshot.liveSignals.length, 7);
      expect(truncationSnapshot.dispatchFeed.length, 6);
    });
  });
}
