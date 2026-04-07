import '../events/decision_created.dart';
import '../events/dispatch_event.dart';
import '../events/execution_completed.dart';
import '../events/execution_denied.dart';
import '../events/guard_checked_in.dart';
import '../events/incident_closed.dart';
import '../events/intelligence_received.dart';
import '../events/patrol_completed.dart';
import '../events/response_arrived.dart';

class SiteHealthSnapshot {
  final String clientId;
  final String regionId;
  final String siteId;
  final int activeDispatches;
  final int executedCount;
  final int deniedCount;
  final int failedCount;
  final int guardCheckIns;
  final int patrolsCompleted;
  final int incidentsClosed;
  final double averageResponseMinutes;
  final double healthScore;
  final String healthStatus;

  const SiteHealthSnapshot({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.activeDispatches,
    required this.executedCount,
    required this.deniedCount,
    required this.failedCount,
    required this.guardCheckIns,
    required this.patrolsCompleted,
    required this.incidentsClosed,
    required this.averageResponseMinutes,
    required this.healthScore,
    required this.healthStatus,
  });
}

class OperationsHealthSnapshot {
  final int totalSites;
  final int totalDecisions;
  final int totalExecuted;
  final int totalDenied;
  final int totalFailed;
  final int totalCheckIns;
  final int totalPatrols;
  final double averageResponseMinutes;
  final double controllerPressureIndex;
  final DateTime lastEventAtUtc;
  final int totalIntelligenceReceived;
  final int highRiskIntelligence;
  final List<String> liveSignals;
  final List<String> dispatchFeed;
  final List<SiteHealthSnapshot> sites;

  const OperationsHealthSnapshot({
    required this.totalSites,
    required this.totalDecisions,
    required this.totalExecuted,
    required this.totalDenied,
    required this.totalFailed,
    required this.totalCheckIns,
    required this.totalPatrols,
    required this.averageResponseMinutes,
    required this.controllerPressureIndex,
    required this.lastEventAtUtc,
    required this.totalIntelligenceReceived,
    required this.highRiskIntelligence,
    required this.liveSignals,
    required this.dispatchFeed,
    required this.sites,
  });
}

class OperationsHealthProjection {
  static OperationsHealthSnapshot build(List<DispatchEvent> events) {
    final decisionTimes = <String, DateTime>{};
    final dispatchStatus = <String, String>{};
    final dispatchSite = <String, String>{};
    final checkInsBySite = <String, int>{};
    final patrolsBySite = <String, int>{};
    final incidentsBySite = <String, int>{};
    final responsesBySite = <String, List<int>>{};
    final allResponseDeltas = <int>[];

    var totalDecisions = 0;
    var totalExecuted = 0;
    var totalDenied = 0;
    var totalFailed = 0;
    var totalCheckIns = 0;
    var totalPatrols = 0;
    var totalIntelligenceReceived = 0;
    var highRiskIntelligence = 0;
    var lastEventAtUtc = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final liveSignals = <String>[];
    final dispatchFeed = <String>[];

    for (final event in events) {
      if (event.occurredAt.isAfter(lastEventAtUtc)) {
        lastEventAtUtc = event.occurredAt;
      }

      if (event is IntelligenceReceived) {
        totalIntelligenceReceived += 1;
        if (event.riskScore >= 70) {
          highRiskIntelligence += 1;
        }
        liveSignals.add(
          'Intel ${event.provider}/${event.externalId} risk ${event.riskScore} at ${event.siteId}.',
        );
      }

      if (event is GuardCheckedIn) {
        final key = _siteKey(event.clientId, event.regionId, event.siteId);
        checkInsBySite.update(key, (value) => value + 1, ifAbsent: () => 1);
        totalCheckIns += 1;
        liveSignals.add(
          'Guard ${event.guardId} checked in at ${event.siteId}.',
        );
      }

      if (event is PatrolCompleted) {
        final key = _siteKey(event.clientId, event.regionId, event.siteId);
        patrolsBySite.update(key, (value) => value + 1, ifAbsent: () => 1);
        totalPatrols += 1;
        liveSignals.add(
          'Patrol ${event.routeId} completed at ${event.siteId}.',
        );
      }

      if (event is IncidentClosed) {
        final key = _siteKey(event.clientId, event.regionId, event.siteId);
        incidentsBySite.update(key, (value) => value + 1, ifAbsent: () => 1);
        liveSignals.add(
          'Incident ${event.dispatchId} closed at ${event.siteId}.',
        );
      }

      if (event is DecisionCreated) {
        totalDecisions += 1;
        decisionTimes[event.dispatchId] = event.occurredAt;
        dispatchStatus[event.dispatchId] = 'DECIDED';
        dispatchSite[event.dispatchId] = _siteKey(
          event.clientId,
          event.regionId,
          event.siteId,
        );
        dispatchFeed.add(
          'Dispatch ${event.dispatchId} DECIDED • ${event.clientId}/${event.siteId}',
        );
      }

      if (event is ExecutionCompleted) {
        dispatchStatus[event.dispatchId] = event.success
            ? 'CONFIRMED'
            : 'FAILED';
        if (event.success) {
          totalExecuted += 1;
          dispatchFeed.add(
            'Dispatch ${event.dispatchId} CONFIRMED • ${event.clientId}/${event.siteId}',
          );
        } else {
          totalFailed += 1;
          dispatchFeed.add(
            'Dispatch ${event.dispatchId} FAILED • ${event.clientId}/${event.siteId}',
          );
        }
      }

      if (event is ExecutionDenied) {
        dispatchStatus[event.dispatchId] = 'DENIED';
        totalDenied += 1;
        dispatchFeed.add(
          'Dispatch ${event.dispatchId} DENIED • ${event.clientId}/${event.siteId}',
        );
      }

      if (event is ResponseArrived) {
        final decisionTime = decisionTimes[event.dispatchId];
        if (decisionTime == null) continue;

        final deltaMs = event.occurredAt
            .difference(decisionTime)
            .inMilliseconds;
        final key = _siteKey(event.clientId, event.regionId, event.siteId);
        responsesBySite.update(
          key,
          (value) => [...value, deltaMs],
          ifAbsent: () => [deltaMs],
        );
        allResponseDeltas.add(deltaMs);
      }
    }

    final siteKeys = <String>{
      ...checkInsBySite.keys,
      ...patrolsBySite.keys,
      ...incidentsBySite.keys,
      ...responsesBySite.keys,
      ...dispatchSite.values,
    }.toList()..sort();

    final dispatchesBySite = <String, List<String>>{};
    dispatchSite.forEach((dispatchId, siteKey) {
      dispatchesBySite.update(
        siteKey,
        (value) => [...value, dispatchId],
        ifAbsent: () => [dispatchId],
      );
    });

    final sites = siteKeys
        .map((siteKey) {
          final siteDispatches = dispatchesBySite[siteKey] ?? const <String>[];
          var active = 0;
          var executed = 0;
          var denied = 0;
          var failed = 0;

          for (final dispatchId in siteDispatches) {
            switch (dispatchStatus[dispatchId]) {
              case 'CONFIRMED':
                executed += 1;
                break;
              case 'DENIED':
                denied += 1;
                break;
              case 'FAILED':
                failed += 1;
                break;
              default:
                active += 1;
                break;
            }
          }

          final responseList = responsesBySite[siteKey] ?? const <int>[];
          final avgResponseMinutes = responseList.isEmpty
              ? 0.0
              : responseList.reduce((a, b) => a + b) /
                    responseList.length /
                    60000.0;

          final checkIns = checkInsBySite[siteKey] ?? 0;
          final patrols = patrolsBySite[siteKey] ?? 0;
          final incidents = incidentsBySite[siteKey] ?? 0;
          final healthScore = _healthScore(
            activeDispatches: active,
            deniedCount: denied,
            failedCount: failed,
            averageResponseMinutes: avgResponseMinutes,
            guardCheckIns: checkIns,
            patrolsCompleted: patrols,
          );

          final healthStatus = healthScore < 45
              ? 'CRITICAL'
              : healthScore < 70
              ? 'WARNING'
              : healthScore < 85
              ? 'STABLE'
              : 'STRONG';

          final parts = siteKey.split('|');
          return SiteHealthSnapshot(
            clientId: parts[0],
            regionId: parts[1],
            siteId: parts[2],
            activeDispatches: active,
            executedCount: executed,
            deniedCount: denied,
            failedCount: failed,
            guardCheckIns: checkIns,
            patrolsCompleted: patrols,
            incidentsClosed: incidents,
            averageResponseMinutes: avgResponseMinutes,
            healthScore: healthScore,
            healthStatus: healthStatus,
          );
        })
        .toList(growable: false);

    final averageResponseMinutes = allResponseDeltas.isEmpty
        ? 0.0
        : allResponseDeltas.reduce((a, b) => a + b) /
              allResponseDeltas.length /
              60000.0;

    final totalActive = sites.fold<int>(
      0,
      (sum, site) => sum + site.activeDispatches,
    );
    final pressureRaw =
        ((totalActive + (totalFailed * 2) + totalDenied) /
            (sites.isEmpty ? 1 : sites.length)) *
        10.0;
    final pressureIndex = pressureRaw.clamp(0.0, 100.0);

    return OperationsHealthSnapshot(
      totalSites: sites.length,
      totalDecisions: totalDecisions,
      totalExecuted: totalExecuted,
      totalDenied: totalDenied,
      totalFailed: totalFailed,
      totalCheckIns: totalCheckIns,
      totalPatrols: totalPatrols,
      averageResponseMinutes: averageResponseMinutes,
      controllerPressureIndex: pressureIndex,
      lastEventAtUtc: lastEventAtUtc,
      totalIntelligenceReceived: totalIntelligenceReceived,
      highRiskIntelligence: highRiskIntelligence,
      liveSignals: liveSignals.reversed.take(7).toList(growable: false),
      dispatchFeed: dispatchFeed.reversed.take(6).toList(growable: false),
      sites: sites,
    );
  }

  static double _healthScore({
    required int activeDispatches,
    required int deniedCount,
    required int failedCount,
    required double averageResponseMinutes,
    required int guardCheckIns,
    required int patrolsCompleted,
  }) {
    final responsePenalty = averageResponseMinutes <= 10
        ? 0.0
        : ((averageResponseMinutes - 10) * 2).clamp(0.0, 25.0);

    final patrolBonus = (patrolsCompleted * 1.5).clamp(0.0, 15.0);
    final checkInBonus = guardCheckIns.clamp(0, 10).toDouble();

    final score =
        100.0 -
        (failedCount * 12.0) -
        (deniedCount * 5.0) -
        (activeDispatches * 3.0) -
        responsePenalty +
        patrolBonus +
        checkInBonus;

    return score.clamp(0.0, 100.0);
  }

  static String _siteKey(String clientId, String regionId, String siteId) =>
      '$clientId|$regionId|$siteId';
}
