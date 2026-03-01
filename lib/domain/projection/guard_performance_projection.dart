import '../events/dispatch_event.dart';
import '../events/guard_checked_in.dart';
import '../events/decision_created.dart';
import '../events/response_arrived.dart';
import '../events/patrol_completed.dart';
import '../events/incident_closed.dart';

class GuardPerformanceProjection {
  final Map<String, int> _guardCheckIns = {};
  final Map<String, int> _patrolCompletions = {};
  final Map<String, List<int>> _patrolDurations = {};

  final Map<String, DateTime> _decisionTimes = {};
  final Map<String, List<int>> _responseTimesMs = {};
  final Map<String, int> _slaBreaches = {};

  final Map<String, int> _incidentCount = {};
  final Map<String, List<int>> _resolutionTimesMs = {};

  static const int _slaThresholdMs = 10 * 60 * 1000;
  static const int _expectedPatrolsPerShift = 8;

  void apply(DispatchEvent event) {
    if (event is GuardCheckedIn) {
      final guardKey =
          _guardKey(event.guardId, event.clientId, event.regionId, event.siteId);

      _guardCheckIns.update(guardKey, (v) => v + 1, ifAbsent: () => 1);
    }

    if (event is PatrolCompleted) {
      final guardKey =
          _guardKey(event.guardId, event.clientId, event.regionId, event.siteId);

      _patrolCompletions.update(guardKey, (v) => v + 1, ifAbsent: () => 1);

      _patrolDurations.update(
        guardKey,
        (list) => [...list, event.durationSeconds],
        ifAbsent: () => [event.durationSeconds],
      );
    }

    if (event is DecisionCreated) {
      _decisionTimes[event.dispatchId] = event.occurredAt;
    }

    if (event is ResponseArrived) {
      final decisionTime = _decisionTimes[event.dispatchId];
      if (decisionTime == null) return;

      final delta = event.occurredAt.difference(decisionTime).inMilliseconds;

      final siteKey = _siteKey(event.clientId, event.regionId, event.siteId);

      _responseTimesMs.update(
        siteKey,
        (list) => [...list, delta],
        ifAbsent: () => [delta],
      );

      if (delta > _slaThresholdMs) {
        _slaBreaches.update(siteKey, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    if (event is IncidentClosed) {
      final decisionTime = _decisionTimes[event.dispatchId];
      if (decisionTime == null) return;

      final resolutionDelta =
          event.occurredAt.difference(decisionTime).inMilliseconds;

      final siteKey = _siteKey(event.clientId, event.regionId, event.siteId);

      _incidentCount.update(siteKey, (v) => v + 1, ifAbsent: () => 1);

      _resolutionTimesMs.update(
        siteKey,
        (list) => [...list, resolutionDelta],
        ifAbsent: () => [resolutionDelta],
      );
    }
  }

  // ---------- Guard Metrics ----------

  int guardCheckIns({
    required String guardId,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    return _guardCheckIns[_guardKey(guardId, clientId, regionId, siteId)] ?? 0;
  }

  int patrolCompletions({
    required String guardId,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    return _patrolCompletions[_guardKey(guardId, clientId, regionId, siteId)] ??
        0;
  }

  double averagePatrolDurationMinutes({
    required String guardId,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final guardKey = _guardKey(guardId, clientId, regionId, siteId);

    final durations = _patrolDurations[guardKey];
    if (durations == null || durations.isEmpty) return 0;

    final avgSeconds =
        durations.reduce((a, b) => a + b) / durations.length;

    return avgSeconds / 60;
  }

  double guardCompliancePercent({
    required String guardId,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final completions = patrolCompletions(
      guardId: guardId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    if (_expectedPatrolsPerShift == 0) return 0;

    return (completions / _expectedPatrolsPerShift) * 100;
  }

  // ---------- Site Metrics ----------

  double averageResponseTimeMinutes({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final siteKey = _siteKey(clientId, regionId, siteId);
    final deltas = _responseTimesMs[siteKey];
    if (deltas == null || deltas.isEmpty) return 0;

    final avgMs = deltas.reduce((a, b) => a + b) / deltas.length;
    return avgMs / 60000;
  }

  double escalationTrendScore({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final siteKey = _siteKey(clientId, regionId, siteId);
    final deltas = _responseTimesMs[siteKey];

    if (deltas == null || deltas.length < 6) return 0;

    final first = deltas.take(3).toList();
    final last = deltas.sublist(deltas.length - 3);

    final firstAvg = first.reduce((a, b) => a + b) / first.length;
    final lastAvg = last.reduce((a, b) => a + b) / last.length;

    if (firstAvg == 0) return 0;

    return (lastAvg - firstAvg) / firstAvg;
  }

  double averageResolutionTimeMinutes({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final siteKey = _siteKey(clientId, regionId, siteId);
    final deltas = _resolutionTimesMs[siteKey];
    if (deltas == null || deltas.isEmpty) return 0;

    final avgMs = deltas.reduce((a, b) => a + b) / deltas.length;
    return avgMs / 60000;
  }

  int incidentCount({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final siteKey = _siteKey(clientId, regionId, siteId);
    return _incidentCount[siteKey] ?? 0;
  }

  int slaBreaches({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final siteKey = _siteKey(clientId, regionId, siteId);
    return _slaBreaches[siteKey] ?? 0;
  }

  double slaCompliancePercent({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final incidents =
        incidentCount(clientId: clientId, regionId: regionId, siteId: siteId);

    if (incidents == 0) return 100;

    final breaches =
        slaBreaches(clientId: clientId, regionId: regionId, siteId: siteId);

    return ((incidents - breaches) / incidents) * 100;
  }

  String _guardKey(
          String guardId, String clientId, String regionId, String siteId) =>
      '$guardId|$clientId|$regionId|$siteId';

  String _siteKey(String clientId, String regionId, String siteId) =>
      '$clientId|$regionId|$siteId';
}
