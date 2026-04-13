import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

class OnyxClientTrustReport {
  final int incidentsHandled;
  final double avgResponseSeconds;
  final double falseAlarmRate;
  final double falseAlarmsReduced;
  final double guardPatrolCompliance;
  final int checkpointsCompleted;
  final double systemUptime;
  final int camerasOnline;
  final int camerasTotal;
  final int alertsDelivered;
  final double avgAwarenessSeconds;
  final int evidenceCertificatesIssued;
  final List<String> topIncidentZones;
  final int saferScore;
  final String saferScoreTrend;
  final String periodLabel;

  const OnyxClientTrustReport({
    required this.incidentsHandled,
    required this.avgResponseSeconds,
    required this.falseAlarmRate,
    required this.falseAlarmsReduced,
    required this.guardPatrolCompliance,
    required this.checkpointsCompleted,
    required this.systemUptime,
    required this.camerasOnline,
    required this.camerasTotal,
    required this.alertsDelivered,
    required this.avgAwarenessSeconds,
    required this.evidenceCertificatesIssued,
    required this.topIncidentZones,
    required this.saferScore,
    required this.saferScoreTrend,
    required this.periodLabel,
  });

  Map<String, Object?> toJsonMap({
    required String clientId,
    required String siteId,
    required DateTimeRange period,
  }) {
    return <String, Object?>{
      'client_id': clientId.trim(),
      'site_id': siteId.trim(),
      'period_start': period.start.toUtc().toIso8601String(),
      'period_end': period.end.toUtc().toIso8601String(),
      'period_label': periodLabel,
      'incidents_handled': incidentsHandled,
      'avg_response_seconds': avgResponseSeconds,
      'false_alarm_rate': falseAlarmRate,
      'false_alarms_reduced': falseAlarmsReduced,
      'guard_patrol_compliance': guardPatrolCompliance,
      'checkpoints_completed': checkpointsCompleted,
      'system_uptime': systemUptime,
      'cameras_online': camerasOnline,
      'cameras_total': camerasTotal,
      'alerts_delivered': alertsDelivered,
      'avg_awareness_seconds': avgAwarenessSeconds,
      'evidence_certificates_issued': evidenceCertificatesIssued,
      'top_incident_zones': topIncidentZones,
      'safer_score': saferScore,
      'safer_score_trend': saferScoreTrend,
      'snapshot_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class OnyxClientTrustService {
  final SupabaseClient _client;
  final DateTime Function() _clock;

  const OnyxClientTrustService({
    required SupabaseClient client,
    DateTime Function()? clock,
  }) : _client = client,
       _clock = clock ?? DateTime.now;

  Future<OnyxClientTrustReport> getClientTrustReport(
    String clientId,
    String siteId,
    DateTimeRange period,
  ) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final current = await _readMetrics(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
      period: period,
    );
    final previousPeriod = DateTimeRange(
      start: period.start.subtract(period.duration),
      end: period.start,
    );
    final previous = await _readMetrics(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
      period: previousPeriod,
    );
    final falseAlarmsReduced = _falseAlarmReduction(
      currentRate: current.falseAlarmRate,
      previousRate: previous.falseAlarmRate,
    );
    final saferScore = _saferScore(current);
    final previousSaferScore = _saferScore(previous);
    return OnyxClientTrustReport(
      incidentsHandled: current.incidentsHandled,
      avgResponseSeconds: current.avgResponseSeconds,
      falseAlarmRate: current.falseAlarmRate,
      falseAlarmsReduced: falseAlarmsReduced,
      guardPatrolCompliance: current.guardPatrolCompliance,
      checkpointsCompleted: current.checkpointsCompleted,
      systemUptime: current.systemUptime,
      camerasOnline: current.camerasOnline,
      camerasTotal: current.camerasTotal,
      alertsDelivered: current.alertsDelivered,
      avgAwarenessSeconds: current.avgAwarenessSeconds,
      evidenceCertificatesIssued: current.evidenceCertificatesIssued,
      topIncidentZones: current.topIncidentZones,
      saferScore: saferScore,
      saferScoreTrend: _trendLabel(
        currentScore: saferScore,
        previousScore: previousSaferScore,
      ),
      periodLabel: _periodLabel(period),
    );
  }

  Future<void> persistWeeklySnapshot({
    required String clientId,
    required String siteId,
    required DateTimeRange period,
  }) async {
    final report = await getClientTrustReport(clientId, siteId, period);
    final payload = report.toJsonMap(
      clientId: clientId,
      siteId: siteId,
      period: period,
    )..['snapshot_at'] = _clock().toUtc().toIso8601String();
    await _client
        .from('onyx_client_trust_snapshots')
        .upsert(
          payload,
          onConflict: 'client_id,site_id,period_start,period_end',
        );
  }

  Future<_TrustMetrics> _readMetrics({
    required String clientId,
    required String siteId,
    required DateTimeRange period,
  }) async {
    final incidents = await _readIncidents(
      clientId: clientId,
      siteId: siteId,
      period: period,
    );
    final outcomes = await _readOutcomes(
      clientId: clientId,
      siteId: siteId,
      period: period,
    );
    final complianceRows = await _readPatrolCompliance(
      siteId: siteId,
      period: period,
    );
    final checkpointScans = await _readCheckpointScans(
      clientId: clientId,
      siteId: siteId,
      period: period,
    );
    final snapshots = await _readSiteAwarenessSnapshots(
      siteId: siteId,
      period: period,
    );
    final latencyRows = await _readAwarenessLatency(
      clientId: clientId,
      siteId: siteId,
      period: period,
    );
    final evidenceRows = await _readEvidenceCertificates(
      clientId: clientId,
      siteId: siteId,
      period: period,
    );

    final responseDurations = incidents
        .map(_incidentResponseSeconds)
        .whereType<double>()
        .toList(growable: false);
    final falseAlarmCount = outcomes.where((row) {
      return _string(row['outcome']) == 'falseAlarm';
    }).length;
    final topZones = _topZonesFromRows(outcomes);
    final compliancePercents = complianceRows
        .map((row) => _double(row['compliance_percent']))
        .whereType<double>()
        .toList(growable: false);
    final checkpointCount = checkpointScans.where((row) {
      final valid = row['valid'];
      return valid == null || valid == true;
    }).length;
    final uptime = _systemUptimeFromSnapshots(snapshots);
    final latestCameraState = _latestCameraStateFromSnapshots(snapshots);
    final totalMs = latencyRows
        .map((row) => _double(row['total_ms']))
        .whereType<double>()
        .toList(growable: false);

    return _TrustMetrics(
      incidentsHandled: incidents.length,
      avgResponseSeconds: _average(responseDurations),
      falseAlarmRate: outcomes.isEmpty
          ? 0
          : (falseAlarmCount / outcomes.length) * 100,
      guardPatrolCompliance: _average(compliancePercents),
      checkpointsCompleted: checkpointCount,
      systemUptime: uptime,
      camerasOnline: latestCameraState.$1,
      camerasTotal: latestCameraState.$2,
      alertsDelivered: latencyRows.length,
      avgAwarenessSeconds: _average(totalMs) / 1000,
      evidenceCertificatesIssued: evidenceRows.length,
      topIncidentZones: topZones,
    );
  }

  Future<List<Map<String, dynamic>>> _readIncidents({
    required String clientId,
    required String siteId,
    required DateTimeRange period,
  }) async {
    final dynamic rows = await _client
        .from('incidents')
        .select(
          'incident_id,client_id,site_id,created_at,occurred_at,signal_received_at,dispatch_time,arrival_time,resolution_time',
        )
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .gte('created_at', period.start.toUtc().toIso8601String())
        .lte('created_at', period.end.toUtc().toIso8601String())
        .limit(2000);
    return _rows(rows);
  }

  Future<List<Map<String, dynamic>>> _readOutcomes({
    required String clientId,
    required String siteId,
    required DateTimeRange period,
  }) async {
    final dynamic rows = await _client
        .from('onyx_alert_outcomes')
        .select('zone_id,outcome,occurred_at')
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .gte('occurred_at', period.start.toUtc().toIso8601String())
        .lte('occurred_at', period.end.toUtc().toIso8601String())
        .limit(4000);
    return _rows(rows);
  }

  Future<List<Map<String, dynamic>>> _readPatrolCompliance({
    required String siteId,
    required DateTimeRange period,
  }) async {
    final dynamic rows = await _client
        .from('patrol_compliance')
        .select('compliance_percent,compliance_date')
        .eq('site_id', siteId)
        .gte('compliance_date', _dateOnly(period.start))
        .lte('compliance_date', _dateOnly(period.end))
        .limit(2000);
    return _rows(rows);
  }

  Future<List<Map<String, dynamic>>> _readCheckpointScans({
    required String clientId,
    required String siteId,
    required DateTimeRange period,
  }) async {
    final dynamic rows = await _client
        .from('patrol_checkpoint_scans')
        .select('valid,scanned_at')
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .gte('scanned_at', period.start.toUtc().toIso8601String())
        .lte('scanned_at', period.end.toUtc().toIso8601String())
        .limit(5000);
    return _rows(rows);
  }

  Future<List<Map<String, dynamic>>> _readSiteAwarenessSnapshots({
    required String siteId,
    required DateTimeRange period,
  }) async {
    final dynamic rows = await _client
        .from('site_awareness_snapshots')
        .select('snapshot_at,channels')
        .eq('site_id', siteId)
        .gte('snapshot_at', period.start.toUtc().toIso8601String())
        .lte('snapshot_at', period.end.toUtc().toIso8601String())
        .order('snapshot_at', ascending: false)
        .limit(2000);
    return _rows(rows);
  }

  Future<List<Map<String, dynamic>>> _readAwarenessLatency({
    required String clientId,
    required String siteId,
    required DateTimeRange period,
  }) async {
    final dynamic rows = await _client
        .from('onyx_awareness_latency')
        .select('total_ms,telegram_at')
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .gte('telegram_at', period.start.toUtc().toIso8601String())
        .lte('telegram_at', period.end.toUtc().toIso8601String())
        .limit(4000);
    return _rows(rows);
  }

  Future<List<Map<String, dynamic>>> _readEvidenceCertificates({
    required String clientId,
    required String siteId,
    required DateTimeRange period,
  }) async {
    final dynamic rows = await _client
        .from('onyx_evidence_certificates')
        .select('issued_at')
        .eq('client_id', clientId)
        .eq('site_id', siteId)
        .gte('issued_at', period.start.toUtc().toIso8601String())
        .lte('issued_at', period.end.toUtc().toIso8601String())
        .limit(4000);
    return _rows(rows);
  }

  List<Map<String, dynamic>> _rows(dynamic rows) {
    if (rows is! List) {
      return const <Map<String, dynamic>>[];
    }
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  double? _incidentResponseSeconds(Map<String, dynamic> row) {
    final signalAt =
        _date(row['signal_received_at']) ??
        _date(row['occurred_at']) ??
        _date(row['created_at']);
    final responseAt =
        _date(row['dispatch_time']) ??
        _date(row['arrival_time']) ??
        _date(row['resolution_time']);
    if (signalAt == null || responseAt == null) {
      return null;
    }
    final seconds = responseAt.difference(signalAt).inMilliseconds / 1000;
    return seconds < 0 ? null : seconds;
  }

  List<String> _topZonesFromRows(List<Map<String, dynamic>> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      final zone = _string(row['zone_id']);
      if (zone.isEmpty) {
        continue;
      }
      counts.update(zone, (value) => value + 1, ifAbsent: () => 1);
    }
    final ordered = counts.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));
    return ordered.take(3).map((entry) => entry.key).toList(growable: false);
  }

  double _systemUptimeFromSnapshots(List<Map<String, dynamic>> rows) {
    var online = 0;
    var total = 0;
    for (final row in rows) {
      final channels = _map(row['channels']);
      for (final entry in channels.values) {
        final channel = _map(entry);
        if (channel.isEmpty) {
          continue;
        }
        total += 1;
        final status = _string(channel['status']).toLowerCase();
        final isOnline =
            status.isEmpty ||
            (status != 'videoloss' && status != 'offline' && status != 'fault');
        if (isOnline) {
          online += 1;
        }
      }
    }
    if (total <= 0) {
      return 0;
    }
    return (online / total) * 100;
  }

  (int, int) _latestCameraStateFromSnapshots(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return (0, 0);
    }
    final channels = _map(rows.first['channels']);
    var online = 0;
    var total = 0;
    for (final entry in channels.values) {
      final channel = _map(entry);
      if (channel.isEmpty) {
        continue;
      }
      total += 1;
      final status = _string(channel['status']).toLowerCase();
      if (status.isEmpty ||
          (status != 'videoloss' && status != 'offline' && status != 'fault')) {
        online += 1;
      }
    }
    return (online, total);
  }

  int _saferScore(_TrustMetrics metrics) {
    var score = 0;
    if (metrics.avgResponseSeconds > 0 && metrics.avgResponseSeconds < 5) {
      score += 25;
    }
    if (metrics.falseAlarmRate < 20) {
      score += 25;
    }
    if (metrics.guardPatrolCompliance > 90) {
      score += 25;
    }
    if (metrics.systemUptime > 99) {
      score += 25;
    }
    return score.clamp(0, 100);
  }

  String _trendLabel({required int currentScore, required int previousScore}) {
    if (currentScore >= previousScore + 5) {
      return 'improving';
    }
    if (currentScore <= previousScore - 5) {
      return 'declining';
    }
    return 'stable';
  }

  double _falseAlarmReduction({
    required double currentRate,
    required double previousRate,
  }) {
    if (previousRate <= 0) {
      return currentRate <= 0 ? 0 : 100;
    }
    final change = ((previousRate - currentRate) / previousRate) * 100;
    return double.parse(change.toStringAsFixed(1));
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final sum = values.fold<double>(0, (current, value) => current + value);
    return sum / values.length;
  }

  String _periodLabel(DateTimeRange period) {
    final days = math.max(1, period.duration.inDays);
    if (days >= 28 && days <= 31) {
      return 'Last 30 days';
    }
    if (days == 7) {
      return 'Last 7 days';
    }
    return '${days + 1} day period';
  }

  String _dateOnly(DateTime value) {
    final utc = value.toUtc();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}';
  }

  DateTime? _date(Object? value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toUtc();

  double? _double(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }
}

class _TrustMetrics {
  final int incidentsHandled;
  final double avgResponseSeconds;
  final double falseAlarmRate;
  final double guardPatrolCompliance;
  final int checkpointsCompleted;
  final double systemUptime;
  final int camerasOnline;
  final int camerasTotal;
  final int alertsDelivered;
  final double avgAwarenessSeconds;
  final int evidenceCertificatesIssued;
  final List<String> topIncidentZones;

  const _TrustMetrics({
    required this.incidentsHandled,
    required this.avgResponseSeconds,
    required this.falseAlarmRate,
    required this.guardPatrolCompliance,
    required this.checkpointsCompleted,
    required this.systemUptime,
    required this.camerasOnline,
    required this.camerasTotal,
    required this.alertsDelivered,
    required this.avgAwarenessSeconds,
    required this.evidenceCertificatesIssued,
    required this.topIncidentZones,
  });
}
