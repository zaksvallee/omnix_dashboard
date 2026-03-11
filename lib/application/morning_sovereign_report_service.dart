import 'dart:math' as math;

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/guard/guard_ops_event.dart';
import '../domain/testing/replay_consistency_verifier.dart';

class SovereignReportLedgerIntegrity {
  final int totalEvents;
  final bool hashVerified;
  final int integrityScore;

  const SovereignReportLedgerIntegrity({
    required this.totalEvents,
    required this.hashVerified,
    required this.integrityScore,
  });

  Map<String, Object?> toJson() {
    return {
      'totalEvents': totalEvents,
      'hashVerified': hashVerified,
      'integrityScore': integrityScore,
    };
  }

  factory SovereignReportLedgerIntegrity.fromJson(Map<String, Object?> json) {
    return SovereignReportLedgerIntegrity(
      totalEvents: (json['totalEvents'] as num?)?.toInt() ?? 0,
      hashVerified: json['hashVerified'] == true,
      integrityScore: (json['integrityScore'] as num?)?.toInt() ?? 0,
    );
  }
}

class SovereignReportAiHumanDelta {
  final int aiDecisions;
  final int humanOverrides;
  final Map<String, int> overrideReasons;

  const SovereignReportAiHumanDelta({
    required this.aiDecisions,
    required this.humanOverrides,
    required this.overrideReasons,
  });

  Map<String, Object?> toJson() {
    return {
      'aiDecisions': aiDecisions,
      'humanOverrides': humanOverrides,
      'overrideReasons': overrideReasons,
    };
  }

  factory SovereignReportAiHumanDelta.fromJson(Map<String, Object?> json) {
    final reasonsRaw = json['overrideReasons'];
    final reasons = <String, int>{};
    if (reasonsRaw is Map) {
      for (final entry in reasonsRaw.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        reasons[key] = (entry.value as num?)?.toInt() ?? 0;
      }
    }
    return SovereignReportAiHumanDelta(
      aiDecisions: (json['aiDecisions'] as num?)?.toInt() ?? 0,
      humanOverrides: (json['humanOverrides'] as num?)?.toInt() ?? 0,
      overrideReasons: reasons,
    );
  }
}

class SovereignReportNormDrift {
  final int sitesMonitored;
  final int driftDetected;
  final double avgMatchScore;

  const SovereignReportNormDrift({
    required this.sitesMonitored,
    required this.driftDetected,
    required this.avgMatchScore,
  });

  Map<String, Object?> toJson() {
    return {
      'sitesMonitored': sitesMonitored,
      'driftDetected': driftDetected,
      'avgMatchScore': avgMatchScore,
    };
  }

  factory SovereignReportNormDrift.fromJson(Map<String, Object?> json) {
    return SovereignReportNormDrift(
      sitesMonitored: (json['sitesMonitored'] as num?)?.toInt() ?? 0,
      driftDetected: (json['driftDetected'] as num?)?.toInt() ?? 0,
      avgMatchScore: (json['avgMatchScore'] as num?)?.toDouble() ?? 100,
    );
  }
}

class SovereignReportComplianceBlockage {
  final int psiraExpired;
  final int pdpExpired;
  final int totalBlocked;

  const SovereignReportComplianceBlockage({
    required this.psiraExpired,
    required this.pdpExpired,
    required this.totalBlocked,
  });

  Map<String, Object?> toJson() {
    return {
      'psiraExpired': psiraExpired,
      'pdpExpired': pdpExpired,
      'totalBlocked': totalBlocked,
    };
  }

  factory SovereignReportComplianceBlockage.fromJson(
    Map<String, Object?> json,
  ) {
    return SovereignReportComplianceBlockage(
      psiraExpired: (json['psiraExpired'] as num?)?.toInt() ?? 0,
      pdpExpired: (json['pdpExpired'] as num?)?.toInt() ?? 0,
      totalBlocked: (json['totalBlocked'] as num?)?.toInt() ?? 0,
    );
  }
}

class SovereignReport {
  final String date;
  final DateTime generatedAtUtc;
  final DateTime shiftWindowStartUtc;
  final DateTime shiftWindowEndUtc;
  final SovereignReportLedgerIntegrity ledgerIntegrity;
  final SovereignReportAiHumanDelta aiHumanDelta;
  final SovereignReportNormDrift normDrift;
  final SovereignReportComplianceBlockage complianceBlockage;

  const SovereignReport({
    required this.date,
    required this.generatedAtUtc,
    required this.shiftWindowStartUtc,
    required this.shiftWindowEndUtc,
    required this.ledgerIntegrity,
    required this.aiHumanDelta,
    required this.normDrift,
    required this.complianceBlockage,
  });

  Map<String, Object?> toJson() {
    return {
      'date': date,
      'generatedAtUtc': generatedAtUtc.toIso8601String(),
      'shiftWindowStartUtc': shiftWindowStartUtc.toIso8601String(),
      'shiftWindowEndUtc': shiftWindowEndUtc.toIso8601String(),
      'ledgerIntegrity': ledgerIntegrity.toJson(),
      'aiHumanDelta': aiHumanDelta.toJson(),
      'normDrift': normDrift.toJson(),
      'complianceBlockage': complianceBlockage.toJson(),
    };
  }

  factory SovereignReport.fromJson(Map<String, Object?> json) {
    final ledgerRaw = json['ledgerIntegrity'];
    final aiHumanRaw = json['aiHumanDelta'];
    final normDriftRaw = json['normDrift'];
    final complianceRaw = json['complianceBlockage'];
    return SovereignReport(
      date: (json['date'] as String? ?? '').trim(),
      generatedAtUtc:
          DateTime.tryParse(
            (json['generatedAtUtc'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      shiftWindowStartUtc:
          DateTime.tryParse(
            (json['shiftWindowStartUtc'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      shiftWindowEndUtc:
          DateTime.tryParse(
            (json['shiftWindowEndUtc'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ledgerIntegrity: ledgerRaw is Map
          ? SovereignReportLedgerIntegrity.fromJson(
              ledgerRaw.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const SovereignReportLedgerIntegrity(
              totalEvents: 0,
              hashVerified: false,
              integrityScore: 0,
            ),
      aiHumanDelta: aiHumanRaw is Map
          ? SovereignReportAiHumanDelta.fromJson(
              aiHumanRaw.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const SovereignReportAiHumanDelta(
              aiDecisions: 0,
              humanOverrides: 0,
              overrideReasons: {},
            ),
      normDrift: normDriftRaw is Map
          ? SovereignReportNormDrift.fromJson(
              normDriftRaw.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const SovereignReportNormDrift(
              sitesMonitored: 0,
              driftDetected: 0,
              avgMatchScore: 100,
            ),
      complianceBlockage: complianceRaw is Map
          ? SovereignReportComplianceBlockage.fromJson(
              complianceRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : const SovereignReportComplianceBlockage(
              psiraExpired: 0,
              pdpExpired: 0,
              totalBlocked: 0,
            ),
    );
  }
}

class MorningSovereignReportService {
  const MorningSovereignReportService();

  static DateTime latestCompletedNightShiftEndLocal(DateTime nowLocal) {
    final today0600 = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 6);
    if (nowLocal.isBefore(today0600)) {
      return today0600.subtract(const Duration(days: 1));
    }
    return today0600;
  }

  static String autoRunKeyFor(DateTime nowLocal) {
    final endLocal = latestCompletedNightShiftEndLocal(nowLocal);
    return _dateKey(endLocal);
  }

  SovereignReport generate({
    required DateTime nowUtc,
    required List<DispatchEvent> events,
    required List<GuardOpsMediaUpload> recentMedia,
    required int guardOutcomePolicyDenied24h,
  }) {
    final nowLocal = nowUtc.toLocal();
    final shiftEndLocal = latestCompletedNightShiftEndLocal(nowLocal);
    final shiftStartLocal = shiftEndLocal.subtract(const Duration(hours: 8));
    final shiftStartUtc = shiftStartLocal.toUtc();
    final shiftEndUtc = shiftEndLocal.toUtc();

    final nightEvents = events
        .where(
          (event) =>
              !event.occurredAt.toUtc().isBefore(shiftStartUtc) &&
              event.occurredAt.toUtc().isBefore(shiftEndUtc),
        )
        .toList(growable: false);

    var replayVerified = true;
    try {
      ReplayConsistencyVerifier.verify(nightEvents);
    } catch (_) {
      replayVerified = false;
    }

    final deniedEvents = nightEvents.whereType<ExecutionDenied>().toList(
      growable: false,
    );
    final overrideReasons = <String, int>{};
    for (final denied in deniedEvents) {
      final reason = denied.reason.trim().isEmpty
          ? 'UNSPECIFIED'
          : denied.reason;
      overrideReasons.update(reason, (count) => count + 1, ifAbsent: () => 1);
    }
    final aiDecisions = nightEvents.whereType<DecisionCreated>().length;

    final mediaWindow = recentMedia
        .where(
          (media) =>
              !media.capturedAt.toUtc().isBefore(shiftStartUtc) &&
              media.capturedAt.toUtc().isBefore(shiftEndUtc),
        )
        .toList(growable: false);
    final siteIds = <String>{
      ...nightEvents
          .whereType<IntelligenceReceived>()
          .map((event) => event.siteId.trim())
          .where((siteId) => siteId.isNotEmpty),
      ...mediaWindow
          .map((media) => media.siteId.trim())
          .where((siteId) => siteId.isNotEmpty),
    };
    final observedScores = mediaWindow
        .map(_observedMatchScore)
        .toList(growable: false);
    final avgMatchScore = observedScores.isEmpty
        ? 100.0
        : observedScores.reduce((a, b) => a + b) / observedScores.length;
    final driftDetected = observedScores.where((score) => score < 80).length;

    final psiraExpired = _countReasonToken(overrideReasons, 'psira');
    final pdpExpired = _countReasonToken(overrideReasons, 'pdp');
    final totalBlocked =
        psiraExpired + pdpExpired + guardOutcomePolicyDenied24h;

    return SovereignReport(
      date: _dateKey(shiftEndLocal),
      generatedAtUtc: nowUtc,
      shiftWindowStartUtc: shiftStartUtc,
      shiftWindowEndUtc: shiftEndUtc,
      ledgerIntegrity: SovereignReportLedgerIntegrity(
        totalEvents: nightEvents.length,
        hashVerified: replayVerified,
        integrityScore: replayVerified ? 100 : 0,
      ),
      aiHumanDelta: SovereignReportAiHumanDelta(
        aiDecisions: aiDecisions,
        humanOverrides: deniedEvents.length,
        overrideReasons: overrideReasons,
      ),
      normDrift: SovereignReportNormDrift(
        sitesMonitored: siteIds.length,
        driftDetected: driftDetected,
        avgMatchScore: double.parse(avgMatchScore.toStringAsFixed(1)),
      ),
      complianceBlockage: SovereignReportComplianceBlockage(
        psiraExpired: psiraExpired,
        pdpExpired: pdpExpired,
        totalBlocked: totalBlocked,
      ),
    );
  }

  int _observedMatchScore(GuardOpsMediaUpload media) {
    var score = media.visualNorm.minMatchScore;
    switch (media.status) {
      case GuardMediaUploadStatus.queued:
        score -= 15;
        break;
      case GuardMediaUploadStatus.failed:
        score -= 30;
        break;
      case GuardMediaUploadStatus.uploaded:
        break;
    }
    if (media.visualNorm.mode == GuardVisualNormMode.ir) {
      score -= 5;
    }
    return math.max(0, math.min(100, score));
  }

  int _countReasonToken(Map<String, int> reasons, String token) {
    var count = 0;
    for (final entry in reasons.entries) {
      if (entry.key.toLowerCase().contains(token.toLowerCase())) {
        count += entry.value;
      }
    }
    return count;
  }
}

String _dateKey(DateTime localDate) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${localDate.year}-${two(localDate.month)}-${two(localDate.day)}';
}
