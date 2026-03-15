import 'dart:math' as math;

import 'monitoring_scene_review_store.dart';
import 'vehicle_throughput_summary_formatter.dart';
import 'vehicle_visit_ledger_projector.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/vehicle_visit_review_recorded.dart';
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

class SovereignReportSceneReview {
  final int totalReviews;
  final int modelReviews;
  final int metadataFallbackReviews;
  final int suppressedActions;
  final int incidentAlerts;
  final int repeatUpdates;
  final int escalationCandidates;
  final String topPosture;
  final String actionMixSummary;
  final String latestActionTaken;
  final String recentActionsSummary;
  final String latestSuppressedPattern;

  const SovereignReportSceneReview({
    required this.totalReviews,
    required this.modelReviews,
    required this.metadataFallbackReviews,
    this.suppressedActions = 0,
    this.incidentAlerts = 0,
    this.repeatUpdates = 0,
    required this.escalationCandidates,
    required this.topPosture,
    this.actionMixSummary = '',
    this.latestActionTaken = '',
    this.recentActionsSummary = '',
    this.latestSuppressedPattern = '',
  });

  Map<String, Object?> toJson() {
    return {
      'totalReviews': totalReviews,
      'modelReviews': modelReviews,
      'metadataFallbackReviews': metadataFallbackReviews,
      'suppressedActions': suppressedActions,
      'incidentAlerts': incidentAlerts,
      'repeatUpdates': repeatUpdates,
      'escalationCandidates': escalationCandidates,
      'topPosture': topPosture,
      'actionMixSummary': actionMixSummary,
      'latestActionTaken': latestActionTaken,
      'recentActionsSummary': recentActionsSummary,
      'latestSuppressedPattern': latestSuppressedPattern,
    };
  }

  factory SovereignReportSceneReview.fromJson(Map<String, Object?> json) {
    return SovereignReportSceneReview(
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      modelReviews: (json['modelReviews'] as num?)?.toInt() ?? 0,
      metadataFallbackReviews:
          (json['metadataFallbackReviews'] as num?)?.toInt() ?? 0,
      suppressedActions: (json['suppressedActions'] as num?)?.toInt() ?? 0,
      incidentAlerts: (json['incidentAlerts'] as num?)?.toInt() ?? 0,
      repeatUpdates: (json['repeatUpdates'] as num?)?.toInt() ?? 0,
      escalationCandidates:
          (json['escalationCandidates'] as num?)?.toInt() ?? 0,
      topPosture: (json['topPosture'] as String? ?? '').trim(),
      actionMixSummary: (json['actionMixSummary'] as String? ?? '').trim(),
      latestActionTaken: (json['latestActionTaken'] as String? ?? '').trim(),
      recentActionsSummary: (json['recentActionsSummary'] as String? ?? '')
          .trim(),
      latestSuppressedPattern:
          (json['latestSuppressedPattern'] as String? ?? '').trim(),
    );
  }
}

class SovereignReportReceiptPolicy {
  final int generatedReports;
  final int trackedConfigurationReports;
  final int legacyConfigurationReports;
  final int fullyIncludedReports;
  final int reportsWithOmittedSections;
  final int omittedAiDecisionLogReports;
  final int omittedGuardMetricsReports;
  final String headline;
  final String summaryLine;
  final String latestReportSummary;

  const SovereignReportReceiptPolicy({
    required this.generatedReports,
    required this.trackedConfigurationReports,
    required this.legacyConfigurationReports,
    required this.fullyIncludedReports,
    required this.reportsWithOmittedSections,
    required this.omittedAiDecisionLogReports,
    required this.omittedGuardMetricsReports,
    this.headline = '',
    this.summaryLine = '',
    this.latestReportSummary = '',
  });

  Map<String, Object?> toJson() {
    return {
      'generatedReports': generatedReports,
      'trackedConfigurationReports': trackedConfigurationReports,
      'legacyConfigurationReports': legacyConfigurationReports,
      'fullyIncludedReports': fullyIncludedReports,
      'reportsWithOmittedSections': reportsWithOmittedSections,
      'omittedAiDecisionLogReports': omittedAiDecisionLogReports,
      'omittedGuardMetricsReports': omittedGuardMetricsReports,
      'headline': headline,
      'summaryLine': summaryLine,
      'latestReportSummary': latestReportSummary,
    };
  }

  factory SovereignReportReceiptPolicy.fromJson(Map<String, Object?> json) {
    return SovereignReportReceiptPolicy(
      generatedReports: (json['generatedReports'] as num?)?.toInt() ?? 0,
      trackedConfigurationReports:
          (json['trackedConfigurationReports'] as num?)?.toInt() ?? 0,
      legacyConfigurationReports:
          (json['legacyConfigurationReports'] as num?)?.toInt() ?? 0,
      fullyIncludedReports:
          (json['fullyIncludedReports'] as num?)?.toInt() ?? 0,
      reportsWithOmittedSections:
          (json['reportsWithOmittedSections'] as num?)?.toInt() ?? 0,
      omittedAiDecisionLogReports:
          (json['omittedAiDecisionLogReports'] as num?)?.toInt() ?? 0,
      omittedGuardMetricsReports:
          (json['omittedGuardMetricsReports'] as num?)?.toInt() ?? 0,
      headline: (json['headline'] as String? ?? '').trim(),
      summaryLine: (json['summaryLine'] as String? ?? '').trim(),
      latestReportSummary: (json['latestReportSummary'] as String? ?? '')
          .trim(),
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
  final SovereignReportSceneReview sceneReview;
  final SovereignReportReceiptPolicy receiptPolicy;
  final SovereignReportVehicleThroughput vehicleThroughput;
  final SovereignReportPartnerProgression partnerProgression;

  const SovereignReport({
    required this.date,
    required this.generatedAtUtc,
    required this.shiftWindowStartUtc,
    required this.shiftWindowEndUtc,
    required this.ledgerIntegrity,
    required this.aiHumanDelta,
    required this.normDrift,
    required this.complianceBlockage,
    this.sceneReview = const SovereignReportSceneReview(
      totalReviews: 0,
      modelReviews: 0,
      metadataFallbackReviews: 0,
      suppressedActions: 0,
      incidentAlerts: 0,
      repeatUpdates: 0,
      escalationCandidates: 0,
      topPosture: 'none',
    ),
    this.receiptPolicy = const SovereignReportReceiptPolicy(
      generatedReports: 0,
      trackedConfigurationReports: 0,
      legacyConfigurationReports: 0,
      fullyIncludedReports: 0,
      reportsWithOmittedSections: 0,
      omittedAiDecisionLogReports: 0,
      omittedGuardMetricsReports: 0,
      headline: '',
      summaryLine: '',
      latestReportSummary: '',
    ),
    this.vehicleThroughput = const SovereignReportVehicleThroughput(
      totalVisits: 0,
      completedVisits: 0,
      activeVisits: 0,
      incompleteVisits: 0,
      uniqueVehicles: 0,
      repeatVehicles: 0,
      unknownVehicleEvents: 0,
      peakHourLabel: 'none',
      peakHourVisitCount: 0,
      averageCompletedDwellMinutes: 0,
      suspiciousShortVisitCount: 0,
      loiteringVisitCount: 0,
      workflowHeadline: '',
      summaryLine: '',
      scopeBreakdowns: <SovereignReportVehicleScopeBreakdown>[],
      exceptionVisits: <SovereignReportVehicleVisitException>[],
    ),
    this.partnerProgression = const SovereignReportPartnerProgression(
      dispatchCount: 0,
      declarationCount: 0,
      acceptedCount: 0,
      onSiteCount: 0,
      allClearCount: 0,
      cancelledCount: 0,
      workflowHeadline: '',
      performanceHeadline: '',
      slaHeadline: '',
      summaryLine: '',
      scopeBreakdowns: <SovereignReportPartnerScopeBreakdown>[],
      scoreboardRows: <SovereignReportPartnerScoreboardRow>[],
      dispatchChains: <SovereignReportPartnerDispatchChain>[],
    ),
  });

  SovereignReport copyWith({
    String? date,
    DateTime? generatedAtUtc,
    DateTime? shiftWindowStartUtc,
    DateTime? shiftWindowEndUtc,
    SovereignReportLedgerIntegrity? ledgerIntegrity,
    SovereignReportAiHumanDelta? aiHumanDelta,
    SovereignReportNormDrift? normDrift,
    SovereignReportComplianceBlockage? complianceBlockage,
    SovereignReportSceneReview? sceneReview,
    SovereignReportReceiptPolicy? receiptPolicy,
    SovereignReportVehicleThroughput? vehicleThroughput,
    SovereignReportPartnerProgression? partnerProgression,
  }) {
    return SovereignReport(
      date: date ?? this.date,
      generatedAtUtc: generatedAtUtc ?? this.generatedAtUtc,
      shiftWindowStartUtc: shiftWindowStartUtc ?? this.shiftWindowStartUtc,
      shiftWindowEndUtc: shiftWindowEndUtc ?? this.shiftWindowEndUtc,
      ledgerIntegrity: ledgerIntegrity ?? this.ledgerIntegrity,
      aiHumanDelta: aiHumanDelta ?? this.aiHumanDelta,
      normDrift: normDrift ?? this.normDrift,
      complianceBlockage: complianceBlockage ?? this.complianceBlockage,
      sceneReview: sceneReview ?? this.sceneReview,
      receiptPolicy: receiptPolicy ?? this.receiptPolicy,
      vehicleThroughput: vehicleThroughput ?? this.vehicleThroughput,
      partnerProgression: partnerProgression ?? this.partnerProgression,
    );
  }

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
      'sceneReview': sceneReview.toJson(),
      'receiptPolicy': receiptPolicy.toJson(),
      'vehicleThroughput': vehicleThroughput.toJson(),
      'partnerProgression': partnerProgression.toJson(),
    };
  }

  factory SovereignReport.fromJson(Map<String, Object?> json) {
    final ledgerRaw = json['ledgerIntegrity'];
    final aiHumanRaw = json['aiHumanDelta'];
    final normDriftRaw = json['normDrift'];
    final complianceRaw = json['complianceBlockage'];
    final sceneReviewRaw = json['sceneReview'];
    final receiptPolicyRaw = json['receiptPolicy'];
    final vehicleThroughputRaw = json['vehicleThroughput'];
    final partnerProgressionRaw = json['partnerProgression'];
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
      sceneReview: sceneReviewRaw is Map
          ? SovereignReportSceneReview.fromJson(
              sceneReviewRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : const SovereignReportSceneReview(
              totalReviews: 0,
              modelReviews: 0,
              metadataFallbackReviews: 0,
              suppressedActions: 0,
              incidentAlerts: 0,
              repeatUpdates: 0,
              escalationCandidates: 0,
              topPosture: 'none',
              actionMixSummary: '',
              latestActionTaken: '',
              latestSuppressedPattern: '',
            ),
      receiptPolicy: receiptPolicyRaw is Map
          ? SovereignReportReceiptPolicy.fromJson(
              receiptPolicyRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : const SovereignReportReceiptPolicy(
              generatedReports: 0,
              trackedConfigurationReports: 0,
              legacyConfigurationReports: 0,
              fullyIncludedReports: 0,
              reportsWithOmittedSections: 0,
              omittedAiDecisionLogReports: 0,
              omittedGuardMetricsReports: 0,
              headline: '',
              summaryLine: '',
              latestReportSummary: '',
            ),
      vehicleThroughput: vehicleThroughputRaw is Map
          ? SovereignReportVehicleThroughput.fromJson(
              vehicleThroughputRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : const SovereignReportVehicleThroughput(
              totalVisits: 0,
              completedVisits: 0,
              activeVisits: 0,
              incompleteVisits: 0,
              uniqueVehicles: 0,
              repeatVehicles: 0,
              unknownVehicleEvents: 0,
              peakHourLabel: 'none',
              peakHourVisitCount: 0,
              averageCompletedDwellMinutes: 0,
              suspiciousShortVisitCount: 0,
              loiteringVisitCount: 0,
              workflowHeadline: '',
              summaryLine: '',
              scopeBreakdowns: <SovereignReportVehicleScopeBreakdown>[],
              exceptionVisits: <SovereignReportVehicleVisitException>[],
            ),
      partnerProgression: partnerProgressionRaw is Map
          ? SovereignReportPartnerProgression.fromJson(
              partnerProgressionRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : const SovereignReportPartnerProgression(
              dispatchCount: 0,
              declarationCount: 0,
              acceptedCount: 0,
              onSiteCount: 0,
              allClearCount: 0,
              cancelledCount: 0,
              workflowHeadline: '',
              performanceHeadline: '',
              slaHeadline: '',
              summaryLine: '',
              scopeBreakdowns: <SovereignReportPartnerScopeBreakdown>[],
              scoreboardRows: <SovereignReportPartnerScoreboardRow>[],
              dispatchChains: <SovereignReportPartnerDispatchChain>[],
            ),
    );
  }
}

class SovereignReportPartnerProgression {
  final int dispatchCount;
  final int declarationCount;
  final int acceptedCount;
  final int onSiteCount;
  final int allClearCount;
  final int cancelledCount;
  final String workflowHeadline;
  final String performanceHeadline;
  final String slaHeadline;
  final String summaryLine;
  final List<SovereignReportPartnerScopeBreakdown> scopeBreakdowns;
  final List<SovereignReportPartnerScoreboardRow> scoreboardRows;
  final List<SovereignReportPartnerDispatchChain> dispatchChains;

  const SovereignReportPartnerProgression({
    required this.dispatchCount,
    required this.declarationCount,
    required this.acceptedCount,
    required this.onSiteCount,
    required this.allClearCount,
    required this.cancelledCount,
    this.workflowHeadline = '',
    this.performanceHeadline = '',
    this.slaHeadline = '',
    required this.summaryLine,
    this.scopeBreakdowns = const <SovereignReportPartnerScopeBreakdown>[],
    this.scoreboardRows = const <SovereignReportPartnerScoreboardRow>[],
    this.dispatchChains = const <SovereignReportPartnerDispatchChain>[],
  });

  SovereignReportPartnerProgression copyWith({
    int? dispatchCount,
    int? declarationCount,
    int? acceptedCount,
    int? onSiteCount,
    int? allClearCount,
    int? cancelledCount,
    String? workflowHeadline,
    String? performanceHeadline,
    String? slaHeadline,
    String? summaryLine,
    List<SovereignReportPartnerScopeBreakdown>? scopeBreakdowns,
    List<SovereignReportPartnerScoreboardRow>? scoreboardRows,
    List<SovereignReportPartnerDispatchChain>? dispatchChains,
  }) {
    return SovereignReportPartnerProgression(
      dispatchCount: dispatchCount ?? this.dispatchCount,
      declarationCount: declarationCount ?? this.declarationCount,
      acceptedCount: acceptedCount ?? this.acceptedCount,
      onSiteCount: onSiteCount ?? this.onSiteCount,
      allClearCount: allClearCount ?? this.allClearCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      workflowHeadline: workflowHeadline ?? this.workflowHeadline,
      performanceHeadline: performanceHeadline ?? this.performanceHeadline,
      slaHeadline: slaHeadline ?? this.slaHeadline,
      summaryLine: summaryLine ?? this.summaryLine,
      scopeBreakdowns: scopeBreakdowns ?? this.scopeBreakdowns,
      scoreboardRows: scoreboardRows ?? this.scoreboardRows,
      dispatchChains: dispatchChains ?? this.dispatchChains,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'dispatchCount': dispatchCount,
      'declarationCount': declarationCount,
      'acceptedCount': acceptedCount,
      'onSiteCount': onSiteCount,
      'allClearCount': allClearCount,
      'cancelledCount': cancelledCount,
      'workflowHeadline': workflowHeadline,
      'performanceHeadline': performanceHeadline,
      'slaHeadline': slaHeadline,
      'summaryLine': summaryLine,
      'scopeBreakdowns': scopeBreakdowns
          .map((scope) => scope.toJson())
          .toList(growable: false),
      'scoreboardRows': scoreboardRows
          .map((row) => row.toJson())
          .toList(growable: false),
      'dispatchChains': dispatchChains
          .map((chain) => chain.toJson())
          .toList(growable: false),
    };
  }

  factory SovereignReportPartnerProgression.fromJson(
    Map<String, Object?> json,
  ) {
    final scopeBreakdowns = <SovereignReportPartnerScopeBreakdown>[];
    final scopeBreakdownsRaw = json['scopeBreakdowns'];
    if (scopeBreakdownsRaw is List) {
      for (final item in scopeBreakdownsRaw) {
        if (item is! Map) continue;
        scopeBreakdowns.add(
          SovereignReportPartnerScopeBreakdown.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }
    final scoreboardRows = <SovereignReportPartnerScoreboardRow>[];
    final scoreboardRowsRaw = json['scoreboardRows'];
    if (scoreboardRowsRaw is List) {
      for (final item in scoreboardRowsRaw) {
        if (item is! Map) continue;
        scoreboardRows.add(
          SovereignReportPartnerScoreboardRow.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }
    final dispatchChains = <SovereignReportPartnerDispatchChain>[];
    final dispatchChainsRaw = json['dispatchChains'];
    if (dispatchChainsRaw is List) {
      for (final item in dispatchChainsRaw) {
        if (item is! Map) continue;
        dispatchChains.add(
          SovereignReportPartnerDispatchChain.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }
    return SovereignReportPartnerProgression(
      dispatchCount: (json['dispatchCount'] as num?)?.toInt() ?? 0,
      declarationCount: (json['declarationCount'] as num?)?.toInt() ?? 0,
      acceptedCount: (json['acceptedCount'] as num?)?.toInt() ?? 0,
      onSiteCount: (json['onSiteCount'] as num?)?.toInt() ?? 0,
      allClearCount: (json['allClearCount'] as num?)?.toInt() ?? 0,
      cancelledCount: (json['cancelledCount'] as num?)?.toInt() ?? 0,
      workflowHeadline: (json['workflowHeadline'] as String? ?? '').trim(),
      performanceHeadline: (json['performanceHeadline'] as String? ?? '')
          .trim(),
      slaHeadline: (json['slaHeadline'] as String? ?? '').trim(),
      summaryLine: (json['summaryLine'] as String? ?? '').trim(),
      scopeBreakdowns: scopeBreakdowns,
      scoreboardRows: scoreboardRows,
      dispatchChains: dispatchChains,
    );
  }
}

class SovereignReportPartnerScoreboardRow {
  final String clientId;
  final String siteId;
  final String partnerLabel;
  final int dispatchCount;
  final int strongCount;
  final int onTrackCount;
  final int watchCount;
  final int criticalCount;
  final double averageAcceptedDelayMinutes;
  final double averageOnSiteDelayMinutes;
  final String summaryLine;

  const SovereignReportPartnerScoreboardRow({
    required this.clientId,
    required this.siteId,
    required this.partnerLabel,
    required this.dispatchCount,
    required this.strongCount,
    required this.onTrackCount,
    required this.watchCount,
    required this.criticalCount,
    required this.averageAcceptedDelayMinutes,
    required this.averageOnSiteDelayMinutes,
    required this.summaryLine,
  });

  Map<String, Object?> toJson() {
    return {
      'clientId': clientId,
      'siteId': siteId,
      'partnerLabel': partnerLabel,
      'dispatchCount': dispatchCount,
      'strongCount': strongCount,
      'onTrackCount': onTrackCount,
      'watchCount': watchCount,
      'criticalCount': criticalCount,
      'averageAcceptedDelayMinutes': averageAcceptedDelayMinutes,
      'averageOnSiteDelayMinutes': averageOnSiteDelayMinutes,
      'summaryLine': summaryLine,
    };
  }

  factory SovereignReportPartnerScoreboardRow.fromJson(
    Map<String, Object?> json,
  ) {
    return SovereignReportPartnerScoreboardRow(
      clientId: (json['clientId'] as String? ?? '').trim(),
      siteId: (json['siteId'] as String? ?? '').trim(),
      partnerLabel: (json['partnerLabel'] as String? ?? '').trim(),
      dispatchCount: (json['dispatchCount'] as num?)?.toInt() ?? 0,
      strongCount: (json['strongCount'] as num?)?.toInt() ?? 0,
      onTrackCount: (json['onTrackCount'] as num?)?.toInt() ?? 0,
      watchCount: (json['watchCount'] as num?)?.toInt() ?? 0,
      criticalCount: (json['criticalCount'] as num?)?.toInt() ?? 0,
      averageAcceptedDelayMinutes:
          (json['averageAcceptedDelayMinutes'] as num?)?.toDouble() ?? 0,
      averageOnSiteDelayMinutes:
          (json['averageOnSiteDelayMinutes'] as num?)?.toDouble() ?? 0,
      summaryLine: (json['summaryLine'] as String? ?? '').trim(),
    );
  }
}

class SovereignReportPartnerScopeBreakdown {
  final String clientId;
  final String siteId;
  final int dispatchCount;
  final int declarationCount;
  final PartnerDispatchStatus latestStatus;
  final DateTime latestOccurredAtUtc;
  final String summaryLine;

  const SovereignReportPartnerScopeBreakdown({
    required this.clientId,
    required this.siteId,
    required this.dispatchCount,
    required this.declarationCount,
    required this.latestStatus,
    required this.latestOccurredAtUtc,
    required this.summaryLine,
  });

  Map<String, Object?> toJson() {
    return {
      'clientId': clientId,
      'siteId': siteId,
      'dispatchCount': dispatchCount,
      'declarationCount': declarationCount,
      'latestStatus': latestStatus.name,
      'latestOccurredAtUtc': latestOccurredAtUtc.toIso8601String(),
      'summaryLine': summaryLine,
    };
  }

  factory SovereignReportPartnerScopeBreakdown.fromJson(
    Map<String, Object?> json,
  ) {
    return SovereignReportPartnerScopeBreakdown(
      clientId: (json['clientId'] as String? ?? '').trim(),
      siteId: (json['siteId'] as String? ?? '').trim(),
      dispatchCount: (json['dispatchCount'] as num?)?.toInt() ?? 0,
      declarationCount: (json['declarationCount'] as num?)?.toInt() ?? 0,
      latestStatus: _partnerDispatchStatusFromName(
        (json['latestStatus'] as String? ?? '').trim(),
      ),
      latestOccurredAtUtc:
          DateTime.tryParse(
            (json['latestOccurredAtUtc'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      summaryLine: (json['summaryLine'] as String? ?? '').trim(),
    );
  }
}

class SovereignReportPartnerDispatchChain {
  final String dispatchId;
  final String clientId;
  final String siteId;
  final String partnerLabel;
  final int declarationCount;
  final PartnerDispatchStatus latestStatus;
  final DateTime latestOccurredAtUtc;
  final DateTime? dispatchCreatedAtUtc;
  final DateTime? acceptedAtUtc;
  final DateTime? onSiteAtUtc;
  final DateTime? allClearAtUtc;
  final DateTime? cancelledAtUtc;
  final double? acceptedDelayMinutes;
  final double? onSiteDelayMinutes;
  final String scoreLabel;
  final String scoreReason;
  final String workflowSummary;

  const SovereignReportPartnerDispatchChain({
    required this.dispatchId,
    required this.clientId,
    required this.siteId,
    required this.partnerLabel,
    required this.declarationCount,
    required this.latestStatus,
    required this.latestOccurredAtUtc,
    this.dispatchCreatedAtUtc,
    this.acceptedAtUtc,
    this.onSiteAtUtc,
    this.allClearAtUtc,
    this.cancelledAtUtc,
    this.acceptedDelayMinutes,
    this.onSiteDelayMinutes,
    this.scoreLabel = '',
    this.scoreReason = '',
    this.workflowSummary = '',
  });

  Map<String, Object?> toJson() {
    return {
      'dispatchId': dispatchId,
      'clientId': clientId,
      'siteId': siteId,
      'partnerLabel': partnerLabel,
      'declarationCount': declarationCount,
      'latestStatus': latestStatus.name,
      'latestOccurredAtUtc': latestOccurredAtUtc.toIso8601String(),
      'dispatchCreatedAtUtc': dispatchCreatedAtUtc?.toIso8601String(),
      'acceptedAtUtc': acceptedAtUtc?.toIso8601String(),
      'onSiteAtUtc': onSiteAtUtc?.toIso8601String(),
      'allClearAtUtc': allClearAtUtc?.toIso8601String(),
      'cancelledAtUtc': cancelledAtUtc?.toIso8601String(),
      'acceptedDelayMinutes': acceptedDelayMinutes,
      'onSiteDelayMinutes': onSiteDelayMinutes,
      'scoreLabel': scoreLabel,
      'scoreReason': scoreReason,
      'workflowSummary': workflowSummary,
    };
  }

  factory SovereignReportPartnerDispatchChain.fromJson(
    Map<String, Object?> json,
  ) {
    return SovereignReportPartnerDispatchChain(
      dispatchId: (json['dispatchId'] as String? ?? '').trim(),
      clientId: (json['clientId'] as String? ?? '').trim(),
      siteId: (json['siteId'] as String? ?? '').trim(),
      partnerLabel: (json['partnerLabel'] as String? ?? '').trim(),
      declarationCount: (json['declarationCount'] as num?)?.toInt() ?? 0,
      latestStatus: _partnerDispatchStatusFromName(
        (json['latestStatus'] as String? ?? '').trim(),
      ),
      latestOccurredAtUtc:
          DateTime.tryParse(
            (json['latestOccurredAtUtc'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      dispatchCreatedAtUtc: DateTime.tryParse(
        (json['dispatchCreatedAtUtc'] as String? ?? '').trim(),
      )?.toUtc(),
      acceptedAtUtc: DateTime.tryParse(
        (json['acceptedAtUtc'] as String? ?? '').trim(),
      )?.toUtc(),
      onSiteAtUtc: DateTime.tryParse(
        (json['onSiteAtUtc'] as String? ?? '').trim(),
      )?.toUtc(),
      allClearAtUtc: DateTime.tryParse(
        (json['allClearAtUtc'] as String? ?? '').trim(),
      )?.toUtc(),
      cancelledAtUtc: DateTime.tryParse(
        (json['cancelledAtUtc'] as String? ?? '').trim(),
      )?.toUtc(),
      acceptedDelayMinutes: (json['acceptedDelayMinutes'] as num?)?.toDouble(),
      onSiteDelayMinutes: (json['onSiteDelayMinutes'] as num?)?.toDouble(),
      scoreLabel: (json['scoreLabel'] as String? ?? '').trim(),
      scoreReason: (json['scoreReason'] as String? ?? '').trim(),
      workflowSummary: (json['workflowSummary'] as String? ?? '').trim(),
    );
  }
}

class SovereignReportVehicleThroughput {
  final int totalVisits;
  final int completedVisits;
  final int activeVisits;
  final int incompleteVisits;
  final int uniqueVehicles;
  final int repeatVehicles;
  final int unknownVehicleEvents;
  final String peakHourLabel;
  final int peakHourVisitCount;
  final double averageCompletedDwellMinutes;
  final int suspiciousShortVisitCount;
  final int loiteringVisitCount;
  final String workflowHeadline;
  final String summaryLine;
  final List<SovereignReportVehicleScopeBreakdown> scopeBreakdowns;
  final List<SovereignReportVehicleVisitException> exceptionVisits;

  const SovereignReportVehicleThroughput({
    required this.totalVisits,
    required this.completedVisits,
    required this.activeVisits,
    required this.incompleteVisits,
    required this.uniqueVehicles,
    required this.repeatVehicles,
    required this.unknownVehicleEvents,
    required this.peakHourLabel,
    required this.peakHourVisitCount,
    required this.averageCompletedDwellMinutes,
    required this.suspiciousShortVisitCount,
    required this.loiteringVisitCount,
    this.workflowHeadline = '',
    required this.summaryLine,
    this.scopeBreakdowns = const <SovereignReportVehicleScopeBreakdown>[],
    this.exceptionVisits = const <SovereignReportVehicleVisitException>[],
  });

  SovereignReportVehicleThroughput copyWith({
    int? totalVisits,
    int? completedVisits,
    int? activeVisits,
    int? incompleteVisits,
    int? uniqueVehicles,
    int? repeatVehicles,
    int? unknownVehicleEvents,
    String? peakHourLabel,
    int? peakHourVisitCount,
    double? averageCompletedDwellMinutes,
    int? suspiciousShortVisitCount,
    int? loiteringVisitCount,
    String? workflowHeadline,
    String? summaryLine,
    List<SovereignReportVehicleScopeBreakdown>? scopeBreakdowns,
    List<SovereignReportVehicleVisitException>? exceptionVisits,
  }) {
    return SovereignReportVehicleThroughput(
      totalVisits: totalVisits ?? this.totalVisits,
      completedVisits: completedVisits ?? this.completedVisits,
      activeVisits: activeVisits ?? this.activeVisits,
      incompleteVisits: incompleteVisits ?? this.incompleteVisits,
      uniqueVehicles: uniqueVehicles ?? this.uniqueVehicles,
      repeatVehicles: repeatVehicles ?? this.repeatVehicles,
      unknownVehicleEvents: unknownVehicleEvents ?? this.unknownVehicleEvents,
      peakHourLabel: peakHourLabel ?? this.peakHourLabel,
      peakHourVisitCount: peakHourVisitCount ?? this.peakHourVisitCount,
      averageCompletedDwellMinutes:
          averageCompletedDwellMinutes ?? this.averageCompletedDwellMinutes,
      suspiciousShortVisitCount:
          suspiciousShortVisitCount ?? this.suspiciousShortVisitCount,
      loiteringVisitCount: loiteringVisitCount ?? this.loiteringVisitCount,
      workflowHeadline: workflowHeadline ?? this.workflowHeadline,
      summaryLine: summaryLine ?? this.summaryLine,
      scopeBreakdowns: scopeBreakdowns ?? this.scopeBreakdowns,
      exceptionVisits: exceptionVisits ?? this.exceptionVisits,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'totalVisits': totalVisits,
      'completedVisits': completedVisits,
      'activeVisits': activeVisits,
      'incompleteVisits': incompleteVisits,
      'uniqueVehicles': uniqueVehicles,
      'repeatVehicles': repeatVehicles,
      'unknownVehicleEvents': unknownVehicleEvents,
      'peakHourLabel': peakHourLabel,
      'peakHourVisitCount': peakHourVisitCount,
      'averageCompletedDwellMinutes': averageCompletedDwellMinutes,
      'suspiciousShortVisitCount': suspiciousShortVisitCount,
      'loiteringVisitCount': loiteringVisitCount,
      'workflowHeadline': workflowHeadline,
      'summaryLine': summaryLine,
      'scopeBreakdowns': scopeBreakdowns
          .map((scope) => scope.toJson())
          .toList(growable: false),
      'exceptionVisits': exceptionVisits
          .map((exception) => exception.toJson())
          .toList(growable: false),
    };
  }

  factory SovereignReportVehicleThroughput.fromJson(Map<String, Object?> json) {
    final scopeBreakdowns = <SovereignReportVehicleScopeBreakdown>[];
    final scopeBreakdownsRaw = json['scopeBreakdowns'];
    if (scopeBreakdownsRaw is List) {
      for (final item in scopeBreakdownsRaw) {
        if (item is! Map) continue;
        scopeBreakdowns.add(
          SovereignReportVehicleScopeBreakdown.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }
    final exceptionVisits = <SovereignReportVehicleVisitException>[];
    final exceptionVisitsRaw = json['exceptionVisits'];
    if (exceptionVisitsRaw is List) {
      for (final item in exceptionVisitsRaw) {
        if (item is! Map) continue;
        exceptionVisits.add(
          SovereignReportVehicleVisitException.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }
    return SovereignReportVehicleThroughput(
      totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 0,
      completedVisits: (json['completedVisits'] as num?)?.toInt() ?? 0,
      activeVisits: (json['activeVisits'] as num?)?.toInt() ?? 0,
      incompleteVisits: (json['incompleteVisits'] as num?)?.toInt() ?? 0,
      uniqueVehicles: (json['uniqueVehicles'] as num?)?.toInt() ?? 0,
      repeatVehicles: (json['repeatVehicles'] as num?)?.toInt() ?? 0,
      unknownVehicleEvents:
          (json['unknownVehicleEvents'] as num?)?.toInt() ?? 0,
      peakHourLabel: (json['peakHourLabel'] as String? ?? 'none').trim(),
      peakHourVisitCount: (json['peakHourVisitCount'] as num?)?.toInt() ?? 0,
      averageCompletedDwellMinutes:
          (json['averageCompletedDwellMinutes'] as num?)?.toDouble() ?? 0,
      suspiciousShortVisitCount:
          (json['suspiciousShortVisitCount'] as num?)?.toInt() ?? 0,
      loiteringVisitCount: (json['loiteringVisitCount'] as num?)?.toInt() ?? 0,
      workflowHeadline: (json['workflowHeadline'] as String? ?? '').trim(),
      summaryLine: (json['summaryLine'] as String? ?? '').trim(),
      scopeBreakdowns: scopeBreakdowns,
      exceptionVisits: exceptionVisits,
    );
  }
}

class SovereignReportVehicleScopeBreakdown {
  final String clientId;
  final String siteId;
  final int totalVisits;
  final int completedVisits;
  final int activeVisits;
  final int incompleteVisits;
  final int unknownVehicleEvents;
  final String summaryLine;

  const SovereignReportVehicleScopeBreakdown({
    required this.clientId,
    required this.siteId,
    required this.totalVisits,
    required this.completedVisits,
    required this.activeVisits,
    required this.incompleteVisits,
    required this.unknownVehicleEvents,
    required this.summaryLine,
  });

  Map<String, Object?> toJson() {
    return {
      'clientId': clientId,
      'siteId': siteId,
      'totalVisits': totalVisits,
      'completedVisits': completedVisits,
      'activeVisits': activeVisits,
      'incompleteVisits': incompleteVisits,
      'unknownVehicleEvents': unknownVehicleEvents,
      'summaryLine': summaryLine,
    };
  }

  factory SovereignReportVehicleScopeBreakdown.fromJson(
    Map<String, Object?> json,
  ) {
    return SovereignReportVehicleScopeBreakdown(
      clientId: (json['clientId'] as String? ?? '').trim(),
      siteId: (json['siteId'] as String? ?? '').trim(),
      totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 0,
      completedVisits: (json['completedVisits'] as num?)?.toInt() ?? 0,
      activeVisits: (json['activeVisits'] as num?)?.toInt() ?? 0,
      incompleteVisits: (json['incompleteVisits'] as num?)?.toInt() ?? 0,
      unknownVehicleEvents:
          (json['unknownVehicleEvents'] as num?)?.toInt() ?? 0,
      summaryLine: (json['summaryLine'] as String? ?? '').trim(),
    );
  }
}

class SovereignReportVehicleVisitException {
  final String clientId;
  final String siteId;
  final String vehicleLabel;
  final String statusLabel;
  final String reasonLabel;
  final String workflowSummary;
  final bool operatorReviewed;
  final DateTime? operatorReviewedAtUtc;
  final String operatorStatusOverride;
  final String primaryEventId;
  final DateTime startedAtUtc;
  final DateTime lastSeenAtUtc;
  final double dwellMinutes;
  final List<String> eventIds;
  final List<String> zoneLabels;
  final List<String> intelligenceIds;

  const SovereignReportVehicleVisitException({
    required this.clientId,
    required this.siteId,
    required this.vehicleLabel,
    required this.statusLabel,
    required this.reasonLabel,
    this.workflowSummary = '',
    this.operatorReviewed = false,
    this.operatorReviewedAtUtc,
    this.operatorStatusOverride = '',
    required this.primaryEventId,
    required this.startedAtUtc,
    required this.lastSeenAtUtc,
    required this.dwellMinutes,
    this.eventIds = const <String>[],
    this.zoneLabels = const <String>[],
    this.intelligenceIds = const <String>[],
  });

  SovereignReportVehicleVisitException copyWith({
    String? clientId,
    String? siteId,
    String? vehicleLabel,
    String? statusLabel,
    String? reasonLabel,
    String? workflowSummary,
    bool? operatorReviewed,
    DateTime? operatorReviewedAtUtc,
    bool clearOperatorReviewedAtUtc = false,
    String? operatorStatusOverride,
    String? primaryEventId,
    DateTime? startedAtUtc,
    DateTime? lastSeenAtUtc,
    double? dwellMinutes,
    List<String>? eventIds,
    List<String>? zoneLabels,
    List<String>? intelligenceIds,
  }) {
    return SovereignReportVehicleVisitException(
      clientId: clientId ?? this.clientId,
      siteId: siteId ?? this.siteId,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      statusLabel: statusLabel ?? this.statusLabel,
      reasonLabel: reasonLabel ?? this.reasonLabel,
      workflowSummary: workflowSummary ?? this.workflowSummary,
      operatorReviewed: operatorReviewed ?? this.operatorReviewed,
      operatorReviewedAtUtc: clearOperatorReviewedAtUtc
          ? null
          : (operatorReviewedAtUtc ?? this.operatorReviewedAtUtc),
      operatorStatusOverride:
          operatorStatusOverride ?? this.operatorStatusOverride,
      primaryEventId: primaryEventId ?? this.primaryEventId,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      lastSeenAtUtc: lastSeenAtUtc ?? this.lastSeenAtUtc,
      dwellMinutes: dwellMinutes ?? this.dwellMinutes,
      eventIds: eventIds ?? this.eventIds,
      zoneLabels: zoneLabels ?? this.zoneLabels,
      intelligenceIds: intelligenceIds ?? this.intelligenceIds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'clientId': clientId,
      'siteId': siteId,
      'vehicleLabel': vehicleLabel,
      'statusLabel': statusLabel,
      'reasonLabel': reasonLabel,
      'workflowSummary': workflowSummary,
      'operatorReviewed': operatorReviewed,
      'operatorReviewedAtUtc': operatorReviewedAtUtc?.toIso8601String(),
      'operatorStatusOverride': operatorStatusOverride,
      'primaryEventId': primaryEventId,
      'startedAtUtc': startedAtUtc.toIso8601String(),
      'lastSeenAtUtc': lastSeenAtUtc.toIso8601String(),
      'dwellMinutes': dwellMinutes,
      'eventIds': eventIds,
      'zoneLabels': zoneLabels,
      'intelligenceIds': intelligenceIds,
    };
  }

  factory SovereignReportVehicleVisitException.fromJson(
    Map<String, Object?> json,
  ) {
    final eventIds = <String>[
      for (final item in (json['eventIds'] as List?) ?? const <Object?>[])
        item.toString().trim(),
    ].where((item) => item.isNotEmpty).toList(growable: false);
    final zoneLabels = <String>[
      for (final item in (json['zoneLabels'] as List?) ?? const <Object?>[])
        item.toString().trim(),
    ].where((item) => item.isNotEmpty).toList(growable: false);
    final intelligenceIds = <String>[
      for (final item
          in (json['intelligenceIds'] as List?) ?? const <Object?>[])
        item.toString().trim(),
    ].where((item) => item.isNotEmpty).toList(growable: false);
    return SovereignReportVehicleVisitException(
      clientId: (json['clientId'] as String? ?? '').trim(),
      siteId: (json['siteId'] as String? ?? '').trim(),
      vehicleLabel: (json['vehicleLabel'] as String? ?? '').trim(),
      statusLabel: (json['statusLabel'] as String? ?? '').trim(),
      reasonLabel: (json['reasonLabel'] as String? ?? '').trim(),
      workflowSummary: (json['workflowSummary'] as String? ?? '').trim(),
      operatorReviewed: json['operatorReviewed'] == true,
      operatorReviewedAtUtc: DateTime.tryParse(
        (json['operatorReviewedAtUtc'] as String? ?? '').trim(),
      )?.toUtc(),
      operatorStatusOverride: (json['operatorStatusOverride'] as String? ?? '')
          .trim(),
      primaryEventId: (json['primaryEventId'] as String? ?? '').trim(),
      startedAtUtc:
          DateTime.tryParse(
            (json['startedAtUtc'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastSeenAtUtc:
          DateTime.tryParse(
            (json['lastSeenAtUtc'] as String? ?? '').trim(),
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      dwellMinutes: (json['dwellMinutes'] as num?)?.toDouble() ?? 0,
      eventIds: eventIds,
      zoneLabels: zoneLabels,
      intelligenceIds: intelligenceIds,
    );
  }
}

String sovereignReportVehicleVisitExceptionKey(
  SovereignReportVehicleVisitException exception,
) {
  final primaryEventId = exception.primaryEventId.trim();
  if (primaryEventId.isNotEmpty) {
    return primaryEventId;
  }
  return [
    exception.clientId.trim(),
    exception.siteId.trim(),
    exception.vehicleLabel.trim(),
    exception.startedAtUtc.toUtc().toIso8601String(),
  ].join('|');
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
    Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId =
        const {},
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
    final nightIntel = nightEvents.whereType<IntelligenceReceived>().toList(
      growable: false,
    );
    final reviewedSceneEvents =
        <({IntelligenceReceived event, MonitoringSceneReviewRecord review})>[];
    for (final intel in nightIntel) {
      final review = sceneReviewByIntelligenceId[intel.intelligenceId.trim()];
      if (review != null) {
        reviewedSceneEvents.add((event: intel, review: review));
      }
    }
    final modelReviews = reviewedSceneEvents.where((entry) {
      final normalized = entry.review.sourceLabel.trim().toLowerCase();
      return normalized != 'metadata-only' &&
          !normalized.startsWith('metadata:');
    }).length;
    final metadataFallbackReviews = reviewedSceneEvents.length - modelReviews;
    var suppressedActions = 0;
    var incidentAlerts = 0;
    var repeatUpdates = 0;
    var escalationCandidates = 0;
    for (final entry in reviewedSceneEvents) {
      switch (_sceneReviewDecisionBucket(entry.review)) {
        case _SceneReviewDecisionBucket.suppressed:
          suppressedActions += 1;
        case _SceneReviewDecisionBucket.incident:
          incidentAlerts += 1;
        case _SceneReviewDecisionBucket.repeat:
          repeatUpdates += 1;
        case _SceneReviewDecisionBucket.escalation:
          escalationCandidates += 1;
      }
    }
    final topPosture = _topSceneReviewPosture(
      reviewedSceneEvents.map((entry) => entry.review).toList(growable: false),
    );
    final actionMixSummary = _sceneActionMixSummary(
      incidentAlerts: incidentAlerts,
      repeatUpdates: repeatUpdates,
      escalationCandidates: escalationCandidates,
      suppressedActions: suppressedActions,
    );
    final latestActionTaken = _latestActionTaken(reviewedSceneEvents);
    final recentActionsSummary = _recentActionsSummary(reviewedSceneEvents);
    final latestSuppressedPattern = _latestSuppressedPattern(
      reviewedSceneEvents,
    );
    final receiptPolicy = _buildReceiptPolicy(
      events: nightEvents.whereType<ReportGenerated>().toList(growable: false),
    );
    final vehicleThroughput = _buildVehicleThroughput(
      nowUtc: nowUtc,
      events: nightIntel,
      reviewEvents: events
          .whereType<VehicleVisitReviewRecorded>()
          .where((event) => !event.occurredAt.toUtc().isAfter(nowUtc))
          .toList(growable: false),
    );
    final partnerProgression = _buildPartnerProgression(
      events: nightEvents.whereType<PartnerDispatchStatusDeclared>().toList(
        growable: false,
      ),
      decisions: nightEvents.whereType<DecisionCreated>().toList(
        growable: false,
      ),
    );

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
      sceneReview: SovereignReportSceneReview(
        totalReviews: reviewedSceneEvents.length,
        modelReviews: modelReviews,
        metadataFallbackReviews: metadataFallbackReviews,
        suppressedActions: suppressedActions,
        incidentAlerts: incidentAlerts,
        repeatUpdates: repeatUpdates,
        escalationCandidates: escalationCandidates,
        topPosture: topPosture,
        actionMixSummary: actionMixSummary,
        latestActionTaken: latestActionTaken,
        recentActionsSummary: recentActionsSummary,
        latestSuppressedPattern: latestSuppressedPattern,
      ),
      receiptPolicy: receiptPolicy,
      vehicleThroughput: vehicleThroughput,
      partnerProgression: partnerProgression,
    );
  }

  SovereignReportReceiptPolicy _buildReceiptPolicy({
    required List<ReportGenerated> events,
  }) {
    if (events.isEmpty) {
      return const SovereignReportReceiptPolicy(
        generatedReports: 0,
        trackedConfigurationReports: 0,
        legacyConfigurationReports: 0,
        fullyIncludedReports: 0,
        reportsWithOmittedSections: 0,
        omittedAiDecisionLogReports: 0,
        omittedGuardMetricsReports: 0,
        headline: '',
        summaryLine: '',
        latestReportSummary: '',
      );
    }

    final ordered = [...events]..sort((a, b) {
      final occurredCompare = b.occurredAt.compareTo(a.occurredAt);
      if (occurredCompare != 0) {
        return occurredCompare;
      }
      return b.sequence.compareTo(a.sequence);
    });

    var trackedConfigurationReports = 0;
    var legacyConfigurationReports = 0;
    var fullyIncludedReports = 0;
    var reportsWithOmittedSections = 0;
    var omittedAiDecisionLogReports = 0;
    var omittedGuardMetricsReports = 0;

    for (final event in ordered) {
      final tracked = event.reportSchemaVersion >= 3;
      if (!tracked) {
        legacyConfigurationReports += 1;
        continue;
      }
      trackedConfigurationReports += 1;
      final omitted = <String>[
        if (!event.includeTimeline) 'Incident Timeline',
        if (!event.includeDispatchSummary) 'Dispatch Summary',
        if (!event.includeCheckpointCompliance) 'Checkpoint Compliance',
        if (!event.includeAiDecisionLog) 'AI Decision Log',
        if (!event.includeGuardMetrics) 'Guard Metrics',
      ];
      if (omitted.isEmpty) {
        fullyIncludedReports += 1;
      } else {
        reportsWithOmittedSections += 1;
      }
      if (!event.includeAiDecisionLog) {
        omittedAiDecisionLogReports += 1;
      }
      if (!event.includeGuardMetrics) {
        omittedGuardMetricsReports += 1;
      }
    }

    final latest = ordered.first;
    final latestTracked = latest.reportSchemaVersion >= 3;
    final latestOmitted = <String>[
      if (!latest.includeTimeline) 'Incident Timeline',
      if (!latest.includeDispatchSummary) 'Dispatch Summary',
      if (!latest.includeCheckpointCompliance) 'Checkpoint Compliance',
      if (!latest.includeAiDecisionLog) 'AI Decision Log',
      if (!latest.includeGuardMetrics) 'Guard Metrics',
    ];
    final latestReportSummary = !latestTracked
        ? '${latest.clientId}/${latest.siteId} ${latest.month} used legacy receipt configuration.'
        : latestOmitted.isEmpty
        ? '${latest.clientId}/${latest.siteId} ${latest.month} included all report sections.'
        : '${latest.clientId}/${latest.siteId} ${latest.month} omitted ${latestOmitted.join(', ')}.';

    final headline = reportsWithOmittedSections > 0
        ? '$reportsWithOmittedSections generated reports omitted sections'
        : fullyIncludedReports > 0
        ? '$fullyIncludedReports generated reports kept full policy'
        : legacyConfigurationReports > 0
        ? '$legacyConfigurationReports generated reports used legacy policy'
        : '${events.length} generated reports recorded';

    final summaryLine =
        'Reports ${events.length} • Tracked $trackedConfigurationReports • Legacy $legacyConfigurationReports • Full $fullyIncludedReports • Omitted $reportsWithOmittedSections • AI log omitted $omittedAiDecisionLogReports • Guard metrics omitted $omittedGuardMetricsReports';

    return SovereignReportReceiptPolicy(
      generatedReports: events.length,
      trackedConfigurationReports: trackedConfigurationReports,
      legacyConfigurationReports: legacyConfigurationReports,
      fullyIncludedReports: fullyIncludedReports,
      reportsWithOmittedSections: reportsWithOmittedSections,
      omittedAiDecisionLogReports: omittedAiDecisionLogReports,
      omittedGuardMetricsReports: omittedGuardMetricsReports,
      headline: headline,
      summaryLine: summaryLine,
      latestReportSummary: latestReportSummary,
    );
  }

  SovereignReportPartnerProgression _buildPartnerProgression({
    required List<PartnerDispatchStatusDeclared> events,
    required List<DecisionCreated> decisions,
  }) {
    if (events.isEmpty) {
      return const SovereignReportPartnerProgression(
        dispatchCount: 0,
        declarationCount: 0,
        acceptedCount: 0,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 0,
        workflowHeadline: '',
        performanceHeadline: '',
        slaHeadline: '',
        summaryLine: '',
        scopeBreakdowns: <SovereignReportPartnerScopeBreakdown>[],
        scoreboardRows: <SovereignReportPartnerScoreboardRow>[],
        dispatchChains: <SovereignReportPartnerDispatchChain>[],
      );
    }
    final groupedByDispatch = <String, List<PartnerDispatchStatusDeclared>>{};
    for (final event in events) {
      final dispatchId = event.dispatchId.trim();
      if (dispatchId.isEmpty) {
        continue;
      }
      groupedByDispatch
          .putIfAbsent(dispatchId, () => <PartnerDispatchStatusDeclared>[])
          .add(event);
    }
    if (groupedByDispatch.isEmpty) {
      return const SovereignReportPartnerProgression(
        dispatchCount: 0,
        declarationCount: 0,
        acceptedCount: 0,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 0,
        workflowHeadline: '',
        performanceHeadline: '',
        slaHeadline: '',
        summaryLine: '',
        scopeBreakdowns: <SovereignReportPartnerScopeBreakdown>[],
        scoreboardRows: <SovereignReportPartnerScoreboardRow>[],
        dispatchChains: <SovereignReportPartnerDispatchChain>[],
      );
    }
    final dispatchCreatedAtUtcByDispatchId = <String, DateTime>{
      for (final decision in decisions)
        if (decision.dispatchId.trim().isNotEmpty)
          decision.dispatchId.trim(): decision.occurredAt.toUtc(),
    };
    var acceptedCount = 0;
    var onSiteCount = 0;
    var allClearCount = 0;
    var cancelledCount = 0;
    final acceptedDelayMinutes = <double>[];
    final onSiteDelayMinutes = <double>[];
    final chains = <SovereignReportPartnerDispatchChain>[];
    final groupedByScope = <String, List<PartnerDispatchStatusDeclared>>{};
    for (final entry in groupedByDispatch.entries) {
      final ordered = [...entry.value]..sort(_compareOccurredAtThenSequence);
      final first = ordered.first;
      final latest = ordered.last;
      final dispatchCreatedAtUtc = dispatchCreatedAtUtcByDispatchId[entry.key];
      final firstOccurrenceByStatus = <PartnerDispatchStatus, DateTime>{};
      for (final event in ordered) {
        firstOccurrenceByStatus.putIfAbsent(
          event.status,
          () => event.occurredAt.toUtc(),
        );
        final scopeKey = _partnerScopeKey(event.clientId, event.siteId);
        groupedByScope
            .putIfAbsent(scopeKey, () => <PartnerDispatchStatusDeclared>[])
            .add(event);
      }
      if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.accepted)) {
        acceptedCount += 1;
      }
      if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.onSite)) {
        onSiteCount += 1;
      }
      if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.allClear)) {
        allClearCount += 1;
      }
      if (firstOccurrenceByStatus.containsKey(
        PartnerDispatchStatus.cancelled,
      )) {
        cancelledCount += 1;
      }
      final acceptedDelay = _delayMinutes(
        dispatchCreatedAtUtc,
        firstOccurrenceByStatus[PartnerDispatchStatus.accepted],
      );
      final onSiteDelay = _delayMinutes(
        dispatchCreatedAtUtc,
        firstOccurrenceByStatus[PartnerDispatchStatus.onSite],
      );
      if (acceptedDelay != null) {
        acceptedDelayMinutes.add(acceptedDelay);
      }
      if (onSiteDelay != null) {
        onSiteDelayMinutes.add(onSiteDelay);
      }
      final scoreLabel = _partnerDispatchScoreLabel(
        latestStatus: latest.status,
        acceptedDelayMinutes: acceptedDelay,
        onSiteDelayMinutes: onSiteDelay,
      );
      final scoreReason = _partnerDispatchScoreReason(
        latestStatus: latest.status,
        acceptedDelayMinutes: acceptedDelay,
        onSiteDelayMinutes: onSiteDelay,
      );
      chains.add(
        SovereignReportPartnerDispatchChain(
          dispatchId: entry.key,
          clientId: first.clientId,
          siteId: first.siteId,
          partnerLabel: first.partnerLabel,
          declarationCount: ordered.length,
          latestStatus: latest.status,
          latestOccurredAtUtc: latest.occurredAt.toUtc(),
          dispatchCreatedAtUtc: dispatchCreatedAtUtc,
          acceptedAtUtc:
              firstOccurrenceByStatus[PartnerDispatchStatus.accepted],
          onSiteAtUtc: firstOccurrenceByStatus[PartnerDispatchStatus.onSite],
          allClearAtUtc:
              firstOccurrenceByStatus[PartnerDispatchStatus.allClear],
          cancelledAtUtc:
              firstOccurrenceByStatus[PartnerDispatchStatus.cancelled],
          acceptedDelayMinutes: acceptedDelay,
          onSiteDelayMinutes: onSiteDelay,
          scoreLabel: scoreLabel,
          scoreReason: scoreReason,
          workflowSummary: _partnerDispatchWorkflowSummary(
            firstOccurrenceByStatus,
            latest.status,
          ),
        ),
      );
    }
    chains.sort(
      (a, b) => b.latestOccurredAtUtc.compareTo(a.latestOccurredAtUtc),
    );
    final scopeBreakdowns = <SovereignReportPartnerScopeBreakdown>[];
    for (final entry in groupedByScope.entries) {
      final declarations = [...entry.value]
        ..sort(_compareOccurredAtThenSequence);
      final latest = declarations.last;
      final scope = _partnerScopeFromKey(entry.key);
      final dispatchIds = declarations
          .map((event) => event.dispatchId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      scopeBreakdowns.add(
        SovereignReportPartnerScopeBreakdown(
          clientId: scope.clientId,
          siteId: scope.siteId,
          dispatchCount: dispatchIds.length,
          declarationCount: declarations.length,
          latestStatus: latest.status,
          latestOccurredAtUtc: latest.occurredAt.toUtc(),
          summaryLine: _partnerScopeSummaryLine(
            dispatchCount: dispatchIds.length,
            declarationCount: declarations.length,
            latestStatus: latest.status,
            latestOccurredAtUtc: latest.occurredAt.toUtc(),
          ),
        ),
      );
    }
    scopeBreakdowns.sort((a, b) {
      final dispatchCompare = b.dispatchCount.compareTo(a.dispatchCount);
      if (dispatchCompare != 0) {
        return dispatchCompare;
      }
      return b.latestOccurredAtUtc.compareTo(a.latestOccurredAtUtc);
    });
    final dispatchCount = chains.length;
    final declarationCount = events.length;
    final scoreboardRows = _partnerScoreboardRows(chains);
    return SovereignReportPartnerProgression(
      dispatchCount: dispatchCount,
      declarationCount: declarationCount,
      acceptedCount: acceptedCount,
      onSiteCount: onSiteCount,
      allClearCount: allClearCount,
      cancelledCount: cancelledCount,
      workflowHeadline: _partnerWorkflowHeadline(chains),
      performanceHeadline: _partnerPerformanceHeadline(chains),
      slaHeadline: _partnerSlaHeadline(
        acceptedDelayMinutes: acceptedDelayMinutes,
        onSiteDelayMinutes: onSiteDelayMinutes,
      ),
      summaryLine: _partnerSummaryLine(
        dispatchCount: dispatchCount,
        declarationCount: declarationCount,
        acceptedCount: acceptedCount,
        onSiteCount: onSiteCount,
        allClearCount: allClearCount,
        cancelledCount: cancelledCount,
      ),
      scopeBreakdowns: scopeBreakdowns,
      scoreboardRows: scoreboardRows,
      dispatchChains: chains,
    );
  }

  SovereignReportVehicleThroughput _buildVehicleThroughput({
    required DateTime nowUtc,
    required List<IntelligenceReceived> events,
    List<VehicleVisitReviewRecorded> reviewEvents = const [],
  }) {
    final snapshots = const VehicleVisitLedgerProjector().projectByScope(
      events: events,
      nowUtc: nowUtc,
    );
    if (snapshots.isEmpty) {
      return const SovereignReportVehicleThroughput(
        totalVisits: 0,
        completedVisits: 0,
        activeVisits: 0,
        incompleteVisits: 0,
        uniqueVehicles: 0,
        repeatVehicles: 0,
        unknownVehicleEvents: 0,
        peakHourLabel: 'none',
        peakHourVisitCount: 0,
        averageCompletedDwellMinutes: 0,
        suspiciousShortVisitCount: 0,
        loiteringVisitCount: 0,
        workflowHeadline: '',
        summaryLine: '',
        scopeBreakdowns: <SovereignReportVehicleScopeBreakdown>[],
        exceptionVisits: <SovereignReportVehicleVisitException>[],
      );
    }
    final visits = <VehicleVisitRecord>[
      for (final snapshot in snapshots.values) ...snapshot.visits,
    ];
    final scopeEntries = snapshots.entries.toList(growable: false)
      ..sort((a, b) {
        final countCompare = b.value.summary.totalVisits.compareTo(
          a.value.summary.totalVisits,
        );
        if (countCompare != 0) {
          return countCompare;
        }
        return a.key.compareTo(b.key);
      });
    final vehicleVisitCount = <String, int>{};
    final visitsByHour = <int, int>{};
    var completedVisits = 0;
    var activeVisits = 0;
    var incompleteVisits = 0;
    var totalCompletedMinutes = 0.0;
    var unknownVehicleEvents = 0;
    var suspiciousShortVisitCount = 0;
    var loiteringVisitCount = 0;
    for (final snapshot in snapshots.values) {
      unknownVehicleEvents += snapshot.summary.unknownVehicleEvents;
    }
    for (final visit in visits) {
      vehicleVisitCount[visit.vehicleKey] =
          (vehicleVisitCount[visit.vehicleKey] ?? 0) + 1;
      visitsByHour[visit.startedAtUtc.toUtc().hour] =
          (visitsByHour[visit.startedAtUtc.toUtc().hour] ?? 0) + 1;
      switch (visit.statusAt(nowUtc)) {
        case VehicleVisitStatus.completed:
          completedVisits += 1;
          totalCompletedMinutes += visit.dwell.inSeconds / 60.0;
          if (visit.dwell < const Duration(minutes: 2)) {
            suspiciousShortVisitCount += 1;
          }
        case VehicleVisitStatus.active:
          activeVisits += 1;
        case VehicleVisitStatus.incomplete:
          incompleteVisits += 1;
      }
      if (visit.dwell >= const Duration(minutes: 30)) {
        loiteringVisitCount += 1;
      }
    }
    final peakHourEntry = visitsByHour.entries.fold<MapEntry<int, int>?>(null, (
      best,
      entry,
    ) {
      if (best == null || entry.value > best.value) {
        return entry;
      }
      if (entry.value == best.value && entry.key < best.key) {
        return entry;
      }
      return best;
    });
    final peakHour = peakHourEntry?.key;
    final repeatVehicles = vehicleVisitCount.values.where((count) => count > 1);
    final scopeBreakdowns = <SovereignReportVehicleScopeBreakdown>[
      for (final entry in scopeEntries)
        _buildVehicleScopeBreakdown(scopeKey: entry.key, snapshot: entry.value),
    ];
    final exceptionVisits = <SovereignReportVehicleVisitException>[];
    for (final entry in scopeEntries) {
      for (final visit in entry.value.visits) {
        final exception = _vehicleVisitExceptionForVisit(
          scopeKey: entry.key,
          visit: visit,
          nowUtc: nowUtc,
        );
        if (exception != null) {
          exceptionVisits.add(exception);
        }
      }
    }
    final reviewedExceptions = _applyVehicleVisitReviewEvents(
      exceptions: exceptionVisits,
      reviewEvents: reviewEvents,
    );
    reviewedExceptions.sort((a, b) {
      final severityCompare = _vehicleExceptionPriority(
        a.reasonLabel,
      ).compareTo(_vehicleExceptionPriority(b.reasonLabel));
      if (severityCompare != 0) {
        return severityCompare;
      }
      return b.lastSeenAtUtc.compareTo(a.lastSeenAtUtc);
    });
    final summary = VehicleThroughputSummary(
      totalVisits: visits.length,
      entryCount: visits.where((visit) => visit.sawEntry).length,
      exitCount: visits.where((visit) => visit.sawExit).length,
      completedCount: completedVisits,
      activeCount: activeVisits,
      incompleteCount: incompleteVisits,
      uniqueVehicles: vehicleVisitCount.length,
      repeatVehicles: repeatVehicles.length,
      unknownVehicleEvents: unknownVehicleEvents,
      averageCompletedDwellMinutes: completedVisits == 0
          ? 0
          : totalCompletedMinutes / completedVisits,
      peakHourLabel: peakHour == null
          ? 'none'
          : '${peakHour.toString().padLeft(2, '0')}:00-${((peakHour + 1) % 24).toString().padLeft(2, '0')}:00',
      peakHourVisitCount: peakHourEntry?.value ?? 0,
      suspiciousShortVisitCount: suspiciousShortVisitCount,
      loiteringVisitCount: loiteringVisitCount,
    );
    return SovereignReportVehicleThroughput(
      totalVisits: summary.totalVisits,
      completedVisits: summary.completedCount,
      activeVisits: summary.activeCount,
      incompleteVisits: summary.incompleteCount,
      uniqueVehicles: summary.uniqueVehicles,
      repeatVehicles: summary.repeatVehicles,
      unknownVehicleEvents: summary.unknownVehicleEvents,
      peakHourLabel: summary.peakHourLabel,
      peakHourVisitCount: summary.peakHourVisitCount,
      averageCompletedDwellMinutes: summary.averageCompletedDwellMinutes,
      suspiciousShortVisitCount: summary.suspiciousShortVisitCount,
      loiteringVisitCount: summary.loiteringVisitCount,
      workflowHeadline: _vehicleWorkflowHeadline(visits, nowUtc),
      summaryLine: const VehicleThroughputSummaryFormatter().format(summary),
      scopeBreakdowns: scopeBreakdowns,
      exceptionVisits: reviewedExceptions,
    );
  }

  List<SovereignReportVehicleVisitException> _applyVehicleVisitReviewEvents({
    required List<SovereignReportVehicleVisitException> exceptions,
    required List<VehicleVisitReviewRecorded> reviewEvents,
  }) {
    if (exceptions.isEmpty || reviewEvents.isEmpty) {
      return List<SovereignReportVehicleVisitException>.from(
        exceptions,
        growable: false,
      );
    }
    final latestByVisitKey = <String, VehicleVisitReviewRecorded>{};
    for (final event in reviewEvents) {
      final key = event.vehicleVisitKey.trim();
      if (key.isEmpty) {
        continue;
      }
      final existing = latestByVisitKey[key];
      if (existing == null ||
          event.sequence > existing.sequence ||
          (event.sequence == existing.sequence &&
              event.occurredAt.isAfter(existing.occurredAt))) {
        latestByVisitKey[key] = event;
      }
    }
    return exceptions
        .map((exception) {
          final reviewEvent =
              latestByVisitKey[sovereignReportVehicleVisitExceptionKey(
                exception,
              )];
          if (reviewEvent == null) {
            return exception;
          }
          final overrideLabel = reviewEvent.statusOverride.trim().toUpperCase();
          final effectiveStatus = overrideLabel.isEmpty
              ? exception.statusLabel.trim()
              : overrideLabel;
          final effectiveWorkflow = _applyStatusToWorkflowSummary(
            exception.workflowSummary,
            effectiveStatus,
          );
          return exception.copyWith(
            statusLabel: effectiveStatus,
            workflowSummary: effectiveWorkflow,
            operatorReviewed: reviewEvent.reviewed,
            operatorReviewedAtUtc: reviewEvent.reviewed
                ? reviewEvent.occurredAt.toUtc()
                : null,
            clearOperatorReviewedAtUtc: !reviewEvent.reviewed,
            operatorStatusOverride: overrideLabel,
          );
        })
        .toList(growable: false);
  }

  String _applyStatusToWorkflowSummary(String summary, String statusLabel) {
    final normalizedStatus = statusLabel.trim().toUpperCase();
    if (normalizedStatus.isEmpty) {
      return summary.trim();
    }
    final trimmed = summary.trim();
    if (trimmed.isEmpty) {
      return 'OBSERVED ($normalizedStatus)';
    }
    final statusPattern = RegExp(r'\s*\([A-Z_]+\)\s*$');
    if (statusPattern.hasMatch(trimmed)) {
      return trimmed.replaceFirst(statusPattern, ' ($normalizedStatus)');
    }
    return '$trimmed ($normalizedStatus)';
  }

  SovereignReportVehicleScopeBreakdown _buildVehicleScopeBreakdown({
    required String scopeKey,
    required VehicleVisitLedgerSnapshot snapshot,
  }) {
    final scope = _vehicleScopeFromKey(scopeKey);
    return SovereignReportVehicleScopeBreakdown(
      clientId: scope.clientId,
      siteId: scope.siteId,
      totalVisits: snapshot.summary.totalVisits,
      completedVisits: snapshot.summary.completedCount,
      activeVisits: snapshot.summary.activeCount,
      incompleteVisits: snapshot.summary.incompleteCount,
      unknownVehicleEvents: snapshot.summary.unknownVehicleEvents,
      summaryLine: const VehicleThroughputSummaryFormatter().format(
        snapshot.summary,
      ),
    );
  }

  SovereignReportVehicleVisitException? _vehicleVisitExceptionForVisit({
    required String scopeKey,
    required VehicleVisitRecord visit,
    required DateTime nowUtc,
  }) {
    final status = visit.statusAt(nowUtc);
    String? reasonLabel;
    switch (status) {
      case VehicleVisitStatus.incomplete:
        reasonLabel = 'Incomplete visit';
      case VehicleVisitStatus.active:
        reasonLabel = 'Active at shift close';
      case VehicleVisitStatus.completed:
        if (visit.dwell < const Duration(minutes: 2)) {
          reasonLabel = 'Short completed visit';
        } else if (visit.dwell >= const Duration(minutes: 30)) {
          reasonLabel = 'Loitering visit';
        }
    }
    if (reasonLabel == null) {
      return null;
    }
    final scope = _vehicleScopeFromKey(scopeKey);
    final zoneLabels = visit.zoneLabels
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final intelligenceIds = visit.intelligenceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final eventIds = visit.eventIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    return SovereignReportVehicleVisitException(
      clientId: scope.clientId,
      siteId: scope.siteId,
      vehicleLabel: visit.plateNumber.trim().isEmpty
          ? visit.vehicleKey
          : visit.plateNumber,
      statusLabel: status.name.toUpperCase(),
      reasonLabel: reasonLabel,
      workflowSummary: _vehicleVisitWorkflowSummary(visit, status),
      primaryEventId: eventIds.isEmpty ? '' : eventIds.last,
      startedAtUtc: visit.startedAtUtc.toUtc(),
      lastSeenAtUtc: visit.lastSeenAtUtc.toUtc(),
      dwellMinutes: double.parse(
        (visit.dwell.inSeconds / 60.0).toStringAsFixed(1),
      ),
      eventIds: eventIds,
      zoneLabels: zoneLabels,
      intelligenceIds: intelligenceIds,
    );
  }

  String _vehicleVisitWorkflowSummary(
    VehicleVisitRecord visit,
    VehicleVisitStatus status,
  ) {
    final stages = <String>[
      if (visit.sawEntry) 'ENTRY',
      if (visit.sawService) 'SERVICE',
      if (visit.sawExit) 'EXIT',
      if (!visit.sawEntry && !visit.sawService && !visit.sawExit) 'OBSERVED',
    ];
    return '${stages.join(' -> ')} (${status.name.toUpperCase()})';
  }

  String _vehicleWorkflowHeadline(
    List<VehicleVisitRecord> visits,
    DateTime nowUtc,
  ) {
    if (visits.isEmpty) {
      return '';
    }
    var completed = 0;
    var incompleteService = 0;
    var activeService = 0;
    var incompleteEntry = 0;
    var activeEntry = 0;
    var incompleteObserved = 0;
    var activeObserved = 0;
    for (final visit in visits) {
      final status = visit.statusAt(nowUtc);
      if (status == VehicleVisitStatus.completed) {
        completed += 1;
        continue;
      }
      final stage = visit.sawService
          ? 'service'
          : visit.sawEntry
          ? 'entry'
          : 'observed';
      switch ((status, stage)) {
        case (VehicleVisitStatus.incomplete, 'service'):
          incompleteService += 1;
        case (VehicleVisitStatus.active, 'service'):
          activeService += 1;
        case (VehicleVisitStatus.incomplete, 'entry'):
          incompleteEntry += 1;
        case (VehicleVisitStatus.active, 'entry'):
          activeEntry += 1;
        case (VehicleVisitStatus.incomplete, _):
          incompleteObserved += 1;
        case (VehicleVisitStatus.active, _):
          activeObserved += 1;
        case (VehicleVisitStatus.completed, _):
          break;
      }
    }
    final clauses = <String>[];
    if (completed > 0) {
      clauses.add(
        '$completed completed ${completed == 1 ? 'visit' : 'visits'} reached EXIT',
      );
    }
    if (incompleteService > 0) {
      clauses.add(
        '$incompleteService incomplete ${incompleteService == 1 ? 'visit' : 'visits'} stalled at SERVICE',
      );
    } else if (activeService > 0) {
      clauses.add(
        '$activeService active ${activeService == 1 ? 'visit' : 'visits'} remain${activeService == 1 ? 's' : ''} in SERVICE',
      );
    }
    if (clauses.length < 2 && incompleteEntry > 0) {
      clauses.add(
        '$incompleteEntry incomplete ${incompleteEntry == 1 ? 'visit' : 'visits'} stopped at ENTRY',
      );
    } else if (clauses.length < 2 && activeEntry > 0) {
      clauses.add(
        '$activeEntry active ${activeEntry == 1 ? 'visit' : 'visits'} remain${activeEntry == 1 ? 's' : ''} at ENTRY',
      );
    }
    if (clauses.length < 2 && incompleteObserved > 0) {
      clauses.add(
        '$incompleteObserved incomplete ${incompleteObserved == 1 ? 'visit' : 'visits'} remained OBSERVED',
      );
    } else if (clauses.length < 2 && activeObserved > 0) {
      clauses.add(
        '$activeObserved active ${activeObserved == 1 ? 'visit' : 'visits'} remain${activeObserved == 1 ? 's' : ''} OBSERVED',
      );
    }
    return clauses.join(' • ');
  }

  ({String clientId, String siteId}) _vehicleScopeFromKey(String scopeKey) {
    final separator = scopeKey.indexOf('|');
    if (separator < 0) {
      return (clientId: '', siteId: scopeKey.trim());
    }
    return (
      clientId: scopeKey.substring(0, separator).trim(),
      siteId: scopeKey.substring(separator + 1).trim(),
    );
  }

  int _vehicleExceptionPriority(String reasonLabel) {
    switch (reasonLabel.trim().toLowerCase()) {
      case 'incomplete visit':
        return 0;
      case 'active at shift close':
        return 1;
      case 'short completed visit':
        return 2;
      case 'loitering visit':
        return 3;
      default:
        return 9;
    }
  }

  _SceneReviewDecisionBucket _sceneReviewDecisionBucket(
    MonitoringSceneReviewRecord review,
  ) {
    final decision = review.decisionLabel.trim().toLowerCase();
    final posture = review.postureLabel.trim().toLowerCase();
    if (decision.contains('suppress')) {
      return _SceneReviewDecisionBucket.suppressed;
    }
    if (decision.contains('repeat')) {
      return _SceneReviewDecisionBucket.repeat;
    }
    if (decision.contains('escalation')) {
      return _SceneReviewDecisionBucket.escalation;
    }
    if (decision.contains('alert') || decision.contains('incident')) {
      return _SceneReviewDecisionBucket.incident;
    }
    if (posture.contains('escalation')) {
      return _SceneReviewDecisionBucket.escalation;
    }
    if (posture.contains('repeat')) {
      return _SceneReviewDecisionBucket.repeat;
    }
    if (posture.isNotEmpty) {
      return _SceneReviewDecisionBucket.incident;
    }
    return _SceneReviewDecisionBucket.suppressed;
  }

  String _latestSuppressedPattern(
    List<({IntelligenceReceived event, MonitoringSceneReviewRecord review})>
    reviews,
  ) {
    final sorted = reviews.toList(growable: false)
      ..sort((a, b) => b.event.occurredAt.compareTo(a.event.occurredAt));
    for (final entry in sorted) {
      if (_sceneReviewDecisionBucket(entry.review) !=
          _SceneReviewDecisionBucket.suppressed) {
        continue;
      }
      final detail = entry.review.decisionSummary.trim().isNotEmpty
          ? entry.review.decisionSummary.trim()
          : entry.review.summary.trim();
      return '${entry.event.occurredAt.toUtc().toIso8601String()} • ${_cameraLabel(entry.event.cameraId)} • $detail';
    }
    return '';
  }

  String _latestActionTaken(
    List<({IntelligenceReceived event, MonitoringSceneReviewRecord review})>
    reviews,
  ) {
    final sorted = reviews.toList(growable: false)
      ..sort((a, b) => b.event.occurredAt.compareTo(a.event.occurredAt));
    for (final entry in sorted) {
      if (_sceneReviewDecisionBucket(entry.review) ==
          _SceneReviewDecisionBucket.suppressed) {
        continue;
      }
      final decisionLabel = entry.review.decisionLabel.trim();
      final detail = entry.review.decisionSummary.trim().isNotEmpty
          ? entry.review.decisionSummary.trim()
          : entry.review.summary.trim();
      final parts = <String>[
        entry.event.occurredAt.toUtc().toIso8601String(),
        _cameraLabel(entry.event.cameraId),
      ];
      if (decisionLabel.isNotEmpty) {
        parts.add(decisionLabel);
      }
      if (detail.isNotEmpty) {
        parts.add(detail);
      }
      return parts.join(' • ');
    }
    return '';
  }

  String _recentActionsSummary(
    List<({IntelligenceReceived event, MonitoringSceneReviewRecord review})>
    reviews,
  ) {
    final recentActions = <String>[];
    for (final entry in reviews) {
      if (_sceneReviewDecisionBucket(entry.review) ==
          _SceneReviewDecisionBucket.suppressed) {
        continue;
      }
      final parts = <String>[
        entry.event.occurredAt.toUtc().toIso8601String(),
        _cameraLabel(entry.event.cameraId),
      ];
      final decisionLabel = entry.review.decisionLabel.trim();
      if (decisionLabel.isNotEmpty) {
        parts.add(decisionLabel);
      }
      final detail = entry.review.decisionSummary.trim().isNotEmpty
          ? entry.review.decisionSummary.trim()
          : entry.review.summary.trim();
      if (detail.isNotEmpty) {
        parts.add(detail);
      }
      recentActions.add(parts.join(' • '));
      if (recentActions.length == 2) {
        break;
      }
    }
    if (recentActions.length <= 1) {
      return '';
    }
    return '${recentActions.first} (+${recentActions.length - 1} more)';
  }

  String _cameraLabel(String? cameraId) {
    final normalized = (cameraId ?? '').trim();
    if (normalized.isEmpty) {
      return 'Unspecified';
    }
    final channelMatch = RegExp(r'^channel-(\d+)$').firstMatch(normalized);
    if (channelMatch != null) {
      return 'Camera ${channelMatch.group(1)}';
    }
    final digitsMatch = RegExp(r'^(\d+)$').firstMatch(normalized);
    if (digitsMatch != null) {
      return 'Camera ${digitsMatch.group(1)}';
    }
    return normalized;
  }

  String _sceneActionMixSummary({
    required int incidentAlerts,
    required int repeatUpdates,
    required int escalationCandidates,
    required int suppressedActions,
  }) {
    final parts = <String>[];
    if (incidentAlerts > 0) {
      parts.add(incidentAlerts == 1 ? '1 alert' : '$incidentAlerts alerts');
    }
    if (repeatUpdates > 0) {
      parts.add(
        repeatUpdates == 1
            ? '1 repeat update'
            : '$repeatUpdates repeat updates',
      );
    }
    if (escalationCandidates > 0) {
      parts.add(
        escalationCandidates == 1
            ? '1 escalation'
            : '$escalationCandidates escalations',
      );
    }
    if (suppressedActions > 0) {
      parts.add(
        suppressedActions == 1
            ? '1 suppressed review'
            : '$suppressedActions suppressed reviews',
      );
    }
    return parts.join(' • ');
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

  String _topSceneReviewPosture(List<MonitoringSceneReviewRecord> reviews) {
    if (reviews.isEmpty) {
      return 'none';
    }
    final counts = <String, int>{};
    for (final review in reviews) {
      final posture = review.postureLabel.trim().isEmpty
          ? 'unknown'
          : review.postureLabel.trim().toLowerCase();
      counts.update(posture, (value) => value + 1, ifAbsent: () => 1);
    }
    final sorted = counts.entries.toList(growable: false)
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return sorted.first.key;
  }

  String _partnerWorkflowHeadline(
    List<SovereignReportPartnerDispatchChain> chains,
  ) {
    if (chains.isEmpty) {
      return '';
    }
    final latestByStatus = <PartnerDispatchStatus, int>{};
    for (final chain in chains) {
      latestByStatus.update(
        chain.latestStatus,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final parts = <String>[];
    final allClearCount = latestByStatus[PartnerDispatchStatus.allClear] ?? 0;
    final onSiteCount = latestByStatus[PartnerDispatchStatus.onSite] ?? 0;
    final acceptedCount = latestByStatus[PartnerDispatchStatus.accepted] ?? 0;
    final cancelledCount = latestByStatus[PartnerDispatchStatus.cancelled] ?? 0;
    if (allClearCount > 0) {
      parts.add(
        allClearCount == 1
            ? '1 partner dispatch reached ALL CLEAR'
            : '$allClearCount partner dispatches reached ALL CLEAR',
      );
    }
    if (onSiteCount > 0) {
      parts.add(
        onSiteCount == 1
            ? '1 partner dispatch remains ON SITE'
            : '$onSiteCount partner dispatches remain ON SITE',
      );
    }
    if (acceptedCount > 0) {
      parts.add(
        acceptedCount == 1
            ? '1 partner dispatch is ACCEPTED'
            : '$acceptedCount partner dispatches are ACCEPTED',
      );
    }
    if (cancelledCount > 0) {
      parts.add(
        cancelledCount == 1
            ? '1 partner dispatch was CANCELLED'
            : '$cancelledCount partner dispatches were CANCELLED',
      );
    }
    return parts.join(' • ');
  }

  String _partnerSummaryLine({
    required int dispatchCount,
    required int declarationCount,
    required int acceptedCount,
    required int onSiteCount,
    required int allClearCount,
    required int cancelledCount,
  }) {
    return 'Dispatches $dispatchCount • Declarations $declarationCount • Accept $acceptedCount • On site $onSiteCount • All clear $allClearCount • Cancelled $cancelledCount';
  }

  String _partnerSlaHeadline({
    required List<double> acceptedDelayMinutes,
    required List<double> onSiteDelayMinutes,
  }) {
    final parts = <String>[];
    final acceptedAverage = _averageMinutes(acceptedDelayMinutes);
    final onSiteAverage = _averageMinutes(onSiteDelayMinutes);
    if (acceptedAverage != null) {
      parts.add('Avg accept ${acceptedAverage.toStringAsFixed(1)}m');
    }
    if (onSiteAverage != null) {
      parts.add('Avg on site ${onSiteAverage.toStringAsFixed(1)}m');
    }
    return parts.join(' • ');
  }

  String _partnerPerformanceHeadline(
    List<SovereignReportPartnerDispatchChain> chains,
  ) {
    if (chains.isEmpty) {
      return '';
    }
    final counts = <String, int>{};
    for (final chain in chains) {
      final label = chain.scoreLabel.trim().toUpperCase();
      if (label.isEmpty) {
        continue;
      }
      counts.update(label, (value) => value + 1, ifAbsent: () => 1);
    }
    final orderedLabels = ['STRONG', 'ON TRACK', 'WATCH', 'CRITICAL'];
    final parts = <String>[];
    for (final label in orderedLabels) {
      final count = counts[label] ?? 0;
      if (count == 0) {
        continue;
      }
      final noun = switch (label) {
        'STRONG' => count == 1 ? 'strong response' : 'strong responses',
        'ON TRACK' => count == 1 ? 'on-track response' : 'on-track responses',
        'WATCH' => count == 1 ? 'watch response' : 'watch responses',
        'CRITICAL' => count == 1 ? 'critical response' : 'critical responses',
        _ => count == 1 ? 'response' : 'responses',
      };
      parts.add('$count $noun');
    }
    return parts.join(' • ');
  }

  List<SovereignReportPartnerScoreboardRow> _partnerScoreboardRows(
    List<SovereignReportPartnerDispatchChain> chains,
  ) {
    if (chains.isEmpty) {
      return const <SovereignReportPartnerScoreboardRow>[];
    }
    final grouped = <String, List<SovereignReportPartnerDispatchChain>>{};
    for (final chain in chains) {
      final partnerLabel = chain.partnerLabel.trim();
      final key =
          '${chain.clientId.trim()}::${chain.siteId.trim()}::${partnerLabel.toUpperCase()}';
      grouped
          .putIfAbsent(key, () => <SovereignReportPartnerDispatchChain>[])
          .add(chain);
    }
    final rows = <SovereignReportPartnerScoreboardRow>[];
    for (final chainsForRow in grouped.values) {
      final first = chainsForRow.first;
      var strongCount = 0;
      var onTrackCount = 0;
      var watchCount = 0;
      var criticalCount = 0;
      final acceptedDelays = <double>[];
      final onSiteDelays = <double>[];
      for (final chain in chainsForRow) {
        switch (chain.scoreLabel.trim().toUpperCase()) {
          case 'STRONG':
            strongCount += 1;
          case 'ON TRACK':
            onTrackCount += 1;
          case 'WATCH':
            watchCount += 1;
          case 'CRITICAL':
            criticalCount += 1;
        }
        if (chain.acceptedDelayMinutes != null) {
          acceptedDelays.add(chain.acceptedDelayMinutes!);
        }
        if (chain.onSiteDelayMinutes != null) {
          onSiteDelays.add(chain.onSiteDelayMinutes!);
        }
      }
      final averageAcceptedDelayMinutes = _averageMinutes(acceptedDelays) ?? 0;
      final averageOnSiteDelayMinutes = _averageMinutes(onSiteDelays) ?? 0;
      rows.add(
        SovereignReportPartnerScoreboardRow(
          clientId: first.clientId,
          siteId: first.siteId,
          partnerLabel: first.partnerLabel,
          dispatchCount: chainsForRow.length,
          strongCount: strongCount,
          onTrackCount: onTrackCount,
          watchCount: watchCount,
          criticalCount: criticalCount,
          averageAcceptedDelayMinutes: double.parse(
            averageAcceptedDelayMinutes.toStringAsFixed(1),
          ),
          averageOnSiteDelayMinutes: double.parse(
            averageOnSiteDelayMinutes.toStringAsFixed(1),
          ),
          summaryLine:
              'Dispatches ${chainsForRow.length} • Strong $strongCount • On track $onTrackCount • Watch $watchCount • Critical $criticalCount • Avg accept ${averageAcceptedDelayMinutes.toStringAsFixed(1)}m • Avg on site ${averageOnSiteDelayMinutes.toStringAsFixed(1)}m',
        ),
      );
    }
    rows.sort((a, b) {
      final criticalCompare = b.criticalCount.compareTo(a.criticalCount);
      if (criticalCompare != 0) {
        return criticalCompare;
      }
      final dispatchCompare = b.dispatchCount.compareTo(a.dispatchCount);
      if (dispatchCompare != 0) {
        return dispatchCompare;
      }
      return a.partnerLabel.compareTo(b.partnerLabel);
    });
    return rows;
  }

  String _partnerDispatchScoreLabel({
    required PartnerDispatchStatus latestStatus,
    required double? acceptedDelayMinutes,
    required double? onSiteDelayMinutes,
  }) {
    if (latestStatus == PartnerDispatchStatus.cancelled) {
      return 'CRITICAL';
    }
    if (latestStatus == PartnerDispatchStatus.allClear) {
      if ((acceptedDelayMinutes ?? double.infinity) <= 5 &&
          (onSiteDelayMinutes ?? double.infinity) <= 15) {
        return 'STRONG';
      }
      return 'WATCH';
    }
    if (latestStatus == PartnerDispatchStatus.onSite) {
      if ((acceptedDelayMinutes ?? double.infinity) <= 5 &&
          (onSiteDelayMinutes ?? double.infinity) <= 15) {
        return 'ON TRACK';
      }
      return 'WATCH';
    }
    return 'WATCH';
  }

  String _partnerDispatchScoreReason({
    required PartnerDispatchStatus latestStatus,
    required double? acceptedDelayMinutes,
    required double? onSiteDelayMinutes,
  }) {
    if (latestStatus == PartnerDispatchStatus.cancelled) {
      return 'Dispatch was cancelled before the partner completed the response chain.';
    }
    if (latestStatus == PartnerDispatchStatus.allClear) {
      if ((acceptedDelayMinutes ?? double.infinity) <= 5 &&
          (onSiteDelayMinutes ?? double.infinity) <= 15) {
        return 'Partner reached ALL CLEAR inside target acceptance and on-site windows.';
      }
      return 'Partner completed the response chain, but one or more response windows drifted beyond target.';
    }
    if (latestStatus == PartnerDispatchStatus.onSite) {
      if ((acceptedDelayMinutes ?? double.infinity) <= 5 &&
          (onSiteDelayMinutes ?? double.infinity) <= 15) {
        return 'Partner is on site inside target windows and the response remains active.';
      }
      return 'Partner is on site, but the approach timing drifted beyond target windows.';
    }
    return 'Partner acknowledged the dispatch, but on-site confirmation has not been declared yet.';
  }

  String _partnerScopeSummaryLine({
    required int dispatchCount,
    required int declarationCount,
    required PartnerDispatchStatus latestStatus,
    required DateTime latestOccurredAtUtc,
  }) {
    return 'Dispatches $dispatchCount • Declarations $declarationCount • Latest ${_partnerDispatchStatusLabel(latestStatus)} @ ${latestOccurredAtUtc.toIso8601String()}';
  }

  String _partnerDispatchWorkflowSummary(
    Map<PartnerDispatchStatus, DateTime> firstOccurrenceByStatus,
    PartnerDispatchStatus latestStatus,
  ) {
    final steps = <String>[];
    if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.accepted)) {
      steps.add('ACCEPT');
    }
    if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.onSite)) {
      steps.add('ON SITE');
    }
    if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.allClear)) {
      steps.add('ALL CLEAR');
    }
    if (firstOccurrenceByStatus.containsKey(PartnerDispatchStatus.cancelled)) {
      steps.add('CANCELLED');
    }
    if (steps.isEmpty) {
      steps.add(_partnerDispatchStatusLabel(latestStatus));
    }
    return '${steps.join(' -> ')} (LATEST ${_partnerDispatchStatusLabel(latestStatus)})';
  }

  double? _delayMinutes(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) {
      return null;
    }
    final duration = endUtc.difference(startUtc);
    if (duration.isNegative) {
      return null;
    }
    return double.parse((duration.inSeconds / 60.0).toStringAsFixed(1));
  }

  double? _averageMinutes(List<double> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((left, right) => left + right) / values.length;
  }
}

enum _SceneReviewDecisionBucket { suppressed, incident, repeat, escalation }

int _compareOccurredAtThenSequence(DispatchEvent a, DispatchEvent b) {
  final occurredAtCompare = a.occurredAt.compareTo(b.occurredAt);
  if (occurredAtCompare != 0) {
    return occurredAtCompare;
  }
  return a.sequence.compareTo(b.sequence);
}

String _dateKey(DateTime localDate) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${localDate.year}-${two(localDate.month)}-${two(localDate.day)}';
}

String _partnerScopeKey(String clientId, String siteId) {
  return '${clientId.trim()}::${siteId.trim()}';
}

({String clientId, String siteId}) _partnerScopeFromKey(String scopeKey) {
  final separator = scopeKey.indexOf('::');
  if (separator == -1) {
    return (clientId: '', siteId: '');
  }
  return (
    clientId: scopeKey.substring(0, separator).trim(),
    siteId: scopeKey.substring(separator + 2).trim(),
  );
}

PartnerDispatchStatus _partnerDispatchStatusFromName(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'accepted' => PartnerDispatchStatus.accepted,
    'onsite' => PartnerDispatchStatus.onSite,
    'on_site' => PartnerDispatchStatus.onSite,
    'allclear' => PartnerDispatchStatus.allClear,
    'all_clear' => PartnerDispatchStatus.allClear,
    'cancelled' => PartnerDispatchStatus.cancelled,
    'canceled' => PartnerDispatchStatus.cancelled,
    _ => PartnerDispatchStatus.accepted,
  };
}

String _partnerDispatchStatusLabel(PartnerDispatchStatus status) {
  return switch (status) {
    PartnerDispatchStatus.accepted => 'ACCEPT',
    PartnerDispatchStatus.onSite => 'ON SITE',
    PartnerDispatchStatus.allClear => 'ALL CLEAR',
    PartnerDispatchStatus.cancelled => 'CANCELLED',
  };
}
