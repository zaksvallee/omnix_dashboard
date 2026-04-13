import 'dart:math';

import 'package:supabase/supabase.dart';

class OnyxOperatorScore {
  final String operatorId;
  final String siteId;
  final String period;
  final double avgResponseSeconds;
  final int correctDecisions;
  final int incorrectDecisions;
  final int missedEscalations;
  final int simulationsCompleted;
  final double score;
  final List<String> weaknesses;
  final List<String> recommendations;

  const OnyxOperatorScore({
    required this.operatorId,
    required this.siteId,
    required this.period,
    required this.avgResponseSeconds,
    required this.correctDecisions,
    required this.incorrectDecisions,
    required this.missedEscalations,
    required this.simulationsCompleted,
    required this.score,
    this.weaknesses = const <String>[],
    this.recommendations = const <String>[],
  });

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'operator_id': operatorId,
      'site_id': siteId,
      'period': period,
      'avg_response_seconds': avgResponseSeconds,
      'correct_decisions': correctDecisions,
      'incorrect_decisions': incorrectDecisions,
      'missed_escalations': missedEscalations,
      'simulations_completed': simulationsCompleted,
      'score': score,
      'weaknesses': weaknesses,
      'recommendations': recommendations,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class OnyxOperatorSimulationRecord {
  final String id;
  final String incidentId;
  final String incidentEventUid;
  final String operatorId;
  final String siteId;
  final String clientId;
  final bool simulated;
  final String scenarioType;
  final String expectedDecision;
  final DateTime injectedAt;
  final DateTime? responseAt;
  final DateTime? revealedAt;
  final double? responseSeconds;
  final String? actionTaken;
  final String? escalationDecision;
  final bool completed;
  final double scoreDelta;
  final String resultLabel;
  final String headline;
  final String summary;

  const OnyxOperatorSimulationRecord({
    required this.id,
    required this.incidentId,
    required this.incidentEventUid,
    required this.operatorId,
    required this.siteId,
    required this.clientId,
    required this.simulated,
    required this.scenarioType,
    required this.expectedDecision,
    required this.injectedAt,
    required this.responseAt,
    required this.revealedAt,
    required this.responseSeconds,
    required this.actionTaken,
    required this.escalationDecision,
    required this.completed,
    required this.scoreDelta,
    required this.resultLabel,
    required this.headline,
    required this.summary,
  });

  Map<String, Object?> toInsertMap() {
    return <String, Object?>{
      'id': id,
      'incident_id': incidentId,
      'incident_event_uid': incidentEventUid,
      'operator_id': operatorId,
      'site_id': siteId,
      'client_id': clientId,
      'simulated': simulated,
      'scenario_type': scenarioType,
      'expected_decision': expectedDecision,
      'injected_at': injectedAt.toUtc().toIso8601String(),
      'response_at': responseAt?.toUtc().toIso8601String(),
      'revealed_at': revealedAt?.toUtc().toIso8601String(),
      'response_seconds': responseSeconds,
      'action_taken': actionTaken,
      'escalation_decision': escalationDecision,
      'completed': completed,
      'score_delta': scoreDelta,
      'result_label': resultLabel,
      'headline': headline,
      'summary': summary,
    };
  }

  factory OnyxOperatorSimulationRecord.fromRow(Map<String, dynamic> row) {
    return OnyxOperatorSimulationRecord(
      id: (row['id'] ?? '').toString().trim(),
      incidentId: (row['incident_id'] ?? '').toString().trim(),
      incidentEventUid: (row['incident_event_uid'] ?? '').toString().trim(),
      operatorId: (row['operator_id'] ?? '').toString().trim(),
      siteId: (row['site_id'] ?? '').toString().trim(),
      clientId: (row['client_id'] ?? '').toString().trim(),
      simulated: row['simulated'] == true,
      scenarioType: (row['scenario_type'] ?? '').toString().trim(),
      expectedDecision: (row['expected_decision'] ?? '').toString().trim(),
      injectedAt:
          DateTime.tryParse((row['injected_at'] ?? '').toString())?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      responseAt: DateTime.tryParse(
        (row['response_at'] ?? '').toString(),
      )?.toUtc(),
      revealedAt: DateTime.tryParse(
        (row['revealed_at'] ?? '').toString(),
      )?.toUtc(),
      responseSeconds: _asDouble(row['response_seconds']),
      actionTaken: _trimToNull(row['action_taken']),
      escalationDecision: _trimToNull(row['escalation_decision']),
      completed: row['completed'] == true,
      scoreDelta: _asDouble(row['score_delta']) ?? 0,
      resultLabel: (row['result_label'] ?? '').toString().trim(),
      headline: (row['headline'] ?? '').toString().trim(),
      summary: (row['summary'] ?? '').toString().trim(),
    );
  }
}

class OnyxSimulationEvaluationResult {
  final List<OnyxOperatorSimulationRecord> completed;

  const OnyxSimulationEvaluationResult({
    this.completed = const <OnyxOperatorSimulationRecord>[],
  });
}

class OnyxOperatorDisciplineService {
  final SupabaseClient _client;
  final DateTime Function() _clock;
  final Random _random;

  OnyxOperatorDisciplineService({
    required SupabaseClient client,
    DateTime Function()? clock,
    Random? random,
  }) : _client = client,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  Future<OnyxOperatorSimulationRecord> injectSimulatedIncident(
    String siteId, {
    String clientId = '',
    String operatorId = 'OPERATOR-UNKNOWN',
  }) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      throw ArgumentError('siteId is required.');
    }
    final nowUtc = _clock().toUtc();
    final scenarioType = _random.nextBool() ? 'escalation' : 'false_alarm';
    final expectedDecision = scenarioType == 'escalation'
        ? 'escalate'
        : 'dismiss';
    final simulationId = _uuidV4();
    final incidentEventUid =
        'SIM-$simulationId-${nowUtc.microsecondsSinceEpoch.toString()}';
    final headline = scenarioType == 'escalation'
        ? 'Perimeter activity requires escalation'
        : 'Motion anomaly requires assessment';
    final summary = scenarioType == 'escalation'
        ? 'Operator should escalate this simulated perimeter breach.'
        : 'Operator should dismiss this simulated false alarm after review.';
    final insertedIncident = await _client
        .from('incidents')
        .insert(<String, Object?>{
          'site_id': normalizedSiteId,
          if (clientId.trim().isNotEmpty) 'client_id': clientId.trim(),
          'event_uid': incidentEventUid,
          'status': 'open',
          'incident_type': 'simulated_operator_test',
          'created_at': nowUtc.toIso8601String(),
          'occurred_at': nowUtc.toIso8601String(),
          'signal_received_at': nowUtc.toIso8601String(),
          'controller_notes':
              '$headline\n$summary\nGenerated by ONYX operator discipline.',
          'field_report': 'simulated incident awaiting operator action',
          'simulated': true,
          'simulation_id': simulationId,
        })
        .select('id')
        .single();
    final incidentId = (insertedIncident['id'] ?? '').toString().trim();
    final record = OnyxOperatorSimulationRecord(
      id: simulationId,
      incidentId: incidentId,
      incidentEventUid: incidentEventUid,
      operatorId: operatorId.trim().isEmpty
          ? 'OPERATOR-UNKNOWN'
          : operatorId.trim(),
      siteId: normalizedSiteId,
      clientId: clientId.trim(),
      simulated: true,
      scenarioType: scenarioType,
      expectedDecision: expectedDecision,
      injectedAt: nowUtc,
      responseAt: null,
      revealedAt: null,
      responseSeconds: null,
      actionTaken: null,
      escalationDecision: null,
      completed: false,
      scoreDelta: 0,
      resultLabel: 'pending',
      headline: headline,
      summary: summary,
    );
    await _client
        .from('onyx_operator_simulations')
        .insert(record.toInsertMap());
    return record;
  }

  Future<OnyxSimulationEvaluationResult> evaluatePendingSimulations({
    String? siteId,
  }) async {
    dynamic query = _client
        .from('onyx_operator_simulations')
        .select()
        .eq('completed', false)
        .order('injected_at', ascending: true)
        .limit(100);
    final normalizedSiteId = (siteId ?? '').trim();
    if (normalizedSiteId.isNotEmpty) {
      query = query.eq('site_id', normalizedSiteId);
    }
    final dynamic rows = await query;
    final completed = <OnyxOperatorSimulationRecord>[];
    if (rows is! List) {
      return const OnyxSimulationEvaluationResult();
    }
    for (final raw in rows) {
      if (raw is! Map) {
        continue;
      }
      final simulation = OnyxOperatorSimulationRecord.fromRow(
        Map<String, dynamic>.from(raw),
      );
      final incident = await _readIncident(simulation.incidentId);
      if (incident == null) {
        continue;
      }
      final responseAt =
          _date(incident['dispatch_time']) ??
          _date(incident['resolution_time']);
      if (responseAt == null) {
        continue;
      }
      final actionTaken = _date(incident['dispatch_time']) != null
          ? 'escalated'
          : 'dismissed';
      final evaluation = simulation.copyWithCompleted(
        responseAt: responseAt,
        revealedAt: _clock().toUtc(),
        responseSeconds:
            responseAt
                .difference(simulation.injectedAt.toUtc())
                .inMilliseconds /
            1000,
        actionTaken: actionTaken,
        escalationDecision: actionTaken,
      );
      final scored = _applyScore(evaluation);
      await _client
          .from('onyx_operator_simulations')
          .update(scored.toInsertMap())
          .eq('id', simulation.id);
      await _client
          .from('incidents')
          .update(<String, Object?>{
            'controller_notes':
                '${(incident['controller_notes'] ?? '').toString().trim()}\n\nONYX REVEAL: This incident was a simulation. Result: ${scored.resultLabel}.',
            'field_report': 'simulation_revealed',
            'revealed_at': scored.revealedAt?.toIso8601String(),
          })
          .eq('id', simulation.incidentId);
      await _recomputeScores(
        operatorId: simulation.operatorId,
        siteId: simulation.siteId,
      );
      completed.add(scored);
    }
    return OnyxSimulationEvaluationResult(completed: completed);
  }

  Future<List<OnyxOperatorScore>> getCurrentScores({
    String? siteId,
    String period = 'week',
  }) async {
    dynamic query = _client
        .from('onyx_operator_scores')
        .select()
        .eq('period', period.trim().isEmpty ? 'week' : period.trim())
        .order('score', ascending: false)
        .limit(20);
    final normalizedSiteId = (siteId ?? '').trim();
    if (normalizedSiteId.isNotEmpty) {
      query = query.eq('site_id', normalizedSiteId);
    }
    final dynamic rows = await query;
    if (rows is! List) {
      return const <OnyxOperatorScore>[];
    }
    return rows
        .whereType<Map>()
        .map((row) => _scoreFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<OnyxOperatorSimulationRecord>> recentSimulationResults({
    String? siteId,
    int limit = 10,
  }) async {
    dynamic query = _client
        .from('onyx_operator_simulations')
        .select()
        .eq('completed', true)
        .order('revealed_at', ascending: false)
        .limit(limit);
    final normalizedSiteId = (siteId ?? '').trim();
    if (normalizedSiteId.isNotEmpty) {
      query = query.eq('site_id', normalizedSiteId);
    }
    final dynamic rows = await query;
    if (rows is! List) {
      return const <OnyxOperatorSimulationRecord>[];
    }
    return rows
        .whereType<Map>()
        .map(
          (row) => OnyxOperatorSimulationRecord.fromRow(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> maybeInjectScheduledSimulation({
    required String siteId,
    required String clientId,
    required String operatorId,
    required bool withinMonitoringHours,
  }) async {
    if (!withinMonitoringHours) {
      return false;
    }
    final nowUtc = _clock().toUtc();
    final oneHourAgo = nowUtc.subtract(const Duration(hours: 1));
    final activeRealIncidents = await _activeRealIncidentCount(siteId);
    if (activeRealIncidents > 0) {
      return false;
    }
    final dynamic recentRows = await _client
        .from('onyx_operator_simulations')
        .select('id')
        .eq('site_id', siteId.trim())
        .gte('injected_at', oneHourAgo.toIso8601String())
        .limit(1);
    if (recentRows is List && recentRows.isNotEmpty) {
      return false;
    }
    final shiftStartUtc = nowUtc.subtract(const Duration(hours: 8));
    final dynamic shiftRows = await _client
        .from('onyx_operator_simulations')
        .select('id')
        .eq('site_id', siteId.trim())
        .gte('injected_at', shiftStartUtc.toIso8601String());
    final shiftCount = shiftRows is List ? shiftRows.length : 0;
    final targetCount = 1 + nowUtc.day % 3;
    if (shiftCount >= targetCount) {
      return false;
    }
    final hourlyWindowIndex = nowUtc.hour;
    final shouldInject =
        (hourlyWindowIndex + nowUtc.day) % 2 == 0 || shiftCount == 0;
    if (!shouldInject) {
      return false;
    }
    await injectSimulatedIncident(
      siteId,
      clientId: clientId,
      operatorId: operatorId,
    );
    return true;
  }

  String weeklyReportText({
    required DateTime weekOf,
    required List<OnyxOperatorScore> scores,
  }) {
    final lines = <String>[
      '🎯 Operator Performance — Week of ${_dateLabel(weekOf)}',
    ];
    if (scores.isEmpty) {
      lines.add('No completed simulations this week.');
      return lines.join('\n');
    }
    for (final score in scores.take(5)) {
      lines.add(
        '${score.operatorId}: Score ${score.score.toStringAsFixed(0)}/100',
      );
      lines.add(
        'Avg response: ${score.avgResponseSeconds.toStringAsFixed(0)}s',
      );
      lines.add('Simulations: ${score.simulationsCompleted} completed');
      if (score.weaknesses.isNotEmpty) {
        lines.add('Weakness: ${score.weaknesses.first}');
      }
      if (score.recommendations.isNotEmpty) {
        lines.add('Recommendation: ${score.recommendations.first}');
      }
    }
    return lines.join('\n');
  }

  Future<Map<String, dynamic>?> _readIncident(String incidentId) async {
    if (incidentId.trim().isEmpty) {
      return null;
    }
    final dynamic row = await _client
        .from('incidents')
        .select()
        .eq('id', incidentId.trim())
        .maybeSingle();
    if (row is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(row);
  }

  Future<int> _activeRealIncidentCount(String siteId) async {
    final dynamic rows = await _client
        .from('incidents')
        .select('id,status,simulated')
        .eq('site_id', siteId.trim())
        .neq('status', 'resolved')
        .neq('status', 'closed')
        .limit(50);
    if (rows is! List) {
      return 0;
    }
    return rows.where((row) {
      if (row is! Map) {
        return false;
      }
      return row['simulated'] != true;
    }).length;
  }

  OnyxOperatorSimulationRecord _applyScore(
    OnyxOperatorSimulationRecord record,
  ) {
    var delta = 0.0;
    final responseSeconds = record.responseSeconds ?? 0;
    if (responseSeconds < 30) {
      delta += 20;
    } else if (responseSeconds <= 60) {
      delta += 10;
    } else if (responseSeconds > 120) {
      delta -= 10;
    }
    final expected = record.expectedDecision.trim().toLowerCase();
    final action = (record.actionTaken ?? '').trim().toLowerCase();
    var resultLabel = 'reviewed';
    if (expected == 'escalate' && action == 'escalated') {
      delta += 15;
      resultLabel = 'correct escalation';
    } else if (expected == 'escalate' && action != 'escalated') {
      delta -= 20;
      resultLabel = 'missed escalation';
    } else if (expected == 'dismiss' && action == 'dismissed') {
      delta += 10;
      resultLabel = 'false alarm correctly dismissed';
    } else if (expected == 'dismiss' && action == 'escalated') {
      delta -= 5;
      resultLabel = 'false alarm incorrectly escalated';
    }
    return OnyxOperatorSimulationRecord(
      id: record.id,
      incidentId: record.incidentId,
      incidentEventUid: record.incidentEventUid,
      operatorId: record.operatorId,
      siteId: record.siteId,
      clientId: record.clientId,
      simulated: record.simulated,
      scenarioType: record.scenarioType,
      expectedDecision: record.expectedDecision,
      injectedAt: record.injectedAt,
      responseAt: record.responseAt,
      revealedAt: record.revealedAt,
      responseSeconds: record.responseSeconds,
      actionTaken: record.actionTaken,
      escalationDecision: record.escalationDecision,
      completed: true,
      scoreDelta: delta,
      resultLabel: resultLabel,
      headline: record.headline,
      summary: record.summary,
    );
  }

  Future<void> _recomputeScores({
    required String operatorId,
    required String siteId,
  }) async {
    final completed = await _completedSimulationsFor(operatorId, siteId);
    for (final period in const <String>['week', 'month']) {
      final filtered = completed
          .where((record) {
            final cutoff = period == 'week'
                ? _clock().toUtc().subtract(const Duration(days: 7))
                : _clock().toUtc().subtract(const Duration(days: 30));
            return !record.injectedAt.isBefore(cutoff);
          })
          .toList(growable: false);
      final score = _scoreForPeriod(
        operatorId: operatorId,
        siteId: siteId,
        period: period,
        records: filtered,
      );
      await _client
          .from('onyx_operator_scores')
          .upsert(score.toJsonMap(), onConflict: 'operator_id,site_id,period');
    }
  }

  Future<List<OnyxOperatorSimulationRecord>> _completedSimulationsFor(
    String operatorId,
    String siteId,
  ) async {
    final dynamic rows = await _client
        .from('onyx_operator_simulations')
        .select()
        .eq('operator_id', operatorId.trim())
        .eq('site_id', siteId.trim())
        .eq('completed', true)
        .order('injected_at', ascending: false)
        .limit(200);
    if (rows is! List) {
      return const <OnyxOperatorSimulationRecord>[];
    }
    return rows
        .whereType<Map>()
        .map(
          (row) => OnyxOperatorSimulationRecord.fromRow(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  OnyxOperatorScore _scoreForPeriod({
    required String operatorId,
    required String siteId,
    required String period,
    required List<OnyxOperatorSimulationRecord> records,
  }) {
    if (records.isEmpty) {
      return OnyxOperatorScore(
        operatorId: operatorId,
        siteId: siteId,
        period: period,
        avgResponseSeconds: 0,
        correctDecisions: 0,
        incorrectDecisions: 0,
        missedEscalations: 0,
        simulationsCompleted: 0,
        score: 0,
        weaknesses: const <String>[],
        recommendations: const <String>[],
      );
    }
    final responseValues = records
        .map((record) => record.responseSeconds ?? 0)
        .where((value) => value > 0)
        .toList(growable: false);
    final avgResponse = responseValues.isEmpty
        ? 0
        : responseValues.reduce((a, b) => a + b) / responseValues.length;
    final correctDecisions = records.where((record) {
      final label = record.resultLabel.toLowerCase();
      return label.contains('correct') || label.contains('correctly');
    }).length;
    final missedEscalations = records.where((record) {
      return record.resultLabel.toLowerCase().contains('missed escalation');
    }).length;
    final incorrectDecisions = records.length - correctDecisions;
    final rawScore = records.fold<double>(
      50,
      (current, record) => current + record.scoreDelta,
    );
    final score = rawScore.clamp(0, 100).toDouble();
    final weaknesses = <String>[];
    final recommendations = <String>[];
    if (missedEscalations > 0) {
      weaknesses.add('missed $missedEscalations escalations');
      recommendations.add('review escalation thresholds');
    }
    if (avgResponse > 60) {
      weaknesses.add('response time drifting above 60 seconds');
      recommendations.add('practice first-look triage');
    }
    if (weaknesses.isEmpty) {
      weaknesses.add('no major weaknesses recorded');
      recommendations.add('maintain current operating discipline');
    }
    return OnyxOperatorScore(
      operatorId: operatorId,
      siteId: siteId,
      period: period,
      avgResponseSeconds: avgResponse.toDouble(),
      correctDecisions: correctDecisions,
      incorrectDecisions: incorrectDecisions,
      missedEscalations: missedEscalations,
      simulationsCompleted: records.length,
      score: score,
      weaknesses: weaknesses,
      recommendations: recommendations,
    );
  }

  OnyxOperatorScore _scoreFromRow(Map<String, dynamic> row) {
    return OnyxOperatorScore(
      operatorId: (row['operator_id'] ?? '').toString().trim(),
      siteId: (row['site_id'] ?? '').toString().trim(),
      period: (row['period'] ?? '').toString().trim(),
      avgResponseSeconds: _asDouble(row['avg_response_seconds']) ?? 0,
      correctDecisions: _asInt(row['correct_decisions']) ?? 0,
      incorrectDecisions: _asInt(row['incorrect_decisions']) ?? 0,
      missedEscalations: _asInt(row['missed_escalations']) ?? 0,
      simulationsCompleted: _asInt(row['simulations_completed']) ?? 0,
      score: _asDouble(row['score']) ?? 0,
      weaknesses: _stringList(row['weaknesses']),
      recommendations: _stringList(row['recommendations']),
    );
  }

  String _uuidV4() {
    final values = List<int>.generate(16, (_) => _random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final buffer = StringBuffer();
    for (var index = 0; index < values.length; index += 1) {
      if (index == 4 || index == 6 || index == 8 || index == 10) {
        buffer.write('-');
      }
      buffer.write(values[index].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String _dateLabel(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
  }
}

extension on OnyxOperatorSimulationRecord {
  OnyxOperatorSimulationRecord copyWithCompleted({
    required DateTime responseAt,
    required DateTime revealedAt,
    required double responseSeconds,
    required String actionTaken,
    required String escalationDecision,
  }) {
    return OnyxOperatorSimulationRecord(
      id: id,
      incidentId: incidentId,
      incidentEventUid: incidentEventUid,
      operatorId: operatorId,
      siteId: siteId,
      clientId: clientId,
      simulated: simulated,
      scenarioType: scenarioType,
      expectedDecision: expectedDecision,
      injectedAt: injectedAt,
      responseAt: responseAt,
      revealedAt: revealedAt,
      responseSeconds: responseSeconds,
      actionTaken: actionTaken,
      escalationDecision: escalationDecision,
      completed: true,
      scoreDelta: scoreDelta,
      resultLabel: resultLabel,
      headline: headline,
      summary: summary,
    );
  }
}

DateTime? _date(Object? value) =>
    DateTime.tryParse((value ?? '').toString().trim())?.toUtc();

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse((value ?? '').toString().trim());
}

double? _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '').toString().trim());
}

String? _trimToNull(Object? value) {
  final normalized = (value ?? '').toString().trim();
  return normalized.isEmpty ? null : normalized;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((entry) => entry.toString().trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}
