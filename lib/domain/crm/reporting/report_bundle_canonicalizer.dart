import 'dart:convert';

import 'report_bundle.dart';

class ReportBundleCanonicalizer {
  static String canonicalJson({
    required ReportBundle bundle,
    required String clientId,
    required String siteId,
    required String month,
    required int reportSchemaVersion,
    required int projectionVersion,
    required int eventRangeStart,
    required int eventRangeEnd,
    required int eventCount,
  }) {
    final payload = <String, Object?>{
      'meta': <String, Object?>{
        'clientId': clientId,
        'siteId': siteId,
        'month': month,
        'reportSchemaVersion': reportSchemaVersion,
        'projectionVersion': projectionVersion,
        'eventRangeStart': eventRangeStart,
        'eventRangeEnd': eventRangeEnd,
        'eventCount': eventCount,
      },
      'monthlyReport': <String, Object?>{
        'clientId': bundle.monthlyReport.clientId,
        'month': bundle.monthlyReport.month,
        'slaTierName': bundle.monthlyReport.slaTierName,
        'totalIncidents': bundle.monthlyReport.totalIncidents,
        'totalEscalations': bundle.monthlyReport.totalEscalations,
        'totalSlaBreaches': bundle.monthlyReport.totalSlaBreaches,
        'totalSlaOverrides': bundle.monthlyReport.totalSlaOverrides,
        'totalClientContacts': bundle.monthlyReport.totalClientContacts,
        'slaComplianceRate': double.parse(
          bundle.monthlyReport.slaComplianceRate.toStringAsFixed(6),
        ),
      },
      'executiveSummary': <String, Object?>{
        'headline': bundle.executiveSummary.headline,
        'performanceSummary': bundle.executiveSummary.performanceSummary,
        'slaSummary': bundle.executiveSummary.slaSummary,
        'riskSummary': bundle.executiveSummary.riskSummary,
      },
      'escalationTrend': <String, Object?>{
        'currentMonth': bundle.escalationTrend.currentMonth,
        'previousMonth': bundle.escalationTrend.previousMonth,
        'currentEscalations': bundle.escalationTrend.currentEscalations,
        'previousEscalations': bundle.escalationTrend.previousEscalations,
        'escalationDeltaPercent': double.parse(
          bundle.escalationTrend.escalationDeltaPercent.toStringAsFixed(6),
        ),
        'currentSlaBreaches': bundle.escalationTrend.currentSlaBreaches,
        'previousSlaBreaches': bundle.escalationTrend.previousSlaBreaches,
        'breachDeltaPercent': double.parse(
          bundle.escalationTrend.breachDeltaPercent.toStringAsFixed(6),
        ),
      },
      'siteComparisons': bundle.siteComparisons
          .map(
            (site) => <String, Object?>{
              'siteId': site.siteId,
              'totalIncidents': site.totalIncidents,
              'totalEscalations': site.totalEscalations,
              'totalSlaBreaches': site.totalSlaBreaches,
              'slaComplianceRate': double.parse(
                site.slaComplianceRate.toStringAsFixed(6),
              ),
            },
          )
          .toList(growable: false),
      'clientSnapshot': <String, Object?>{
        'clientId': bundle.clientSnapshot.clientId,
        'clientName': bundle.clientSnapshot.clientName,
        'siteName': bundle.clientSnapshot.siteName,
        'slaTier': bundle.clientSnapshot.slaTier,
        'reportingPeriod': bundle.clientSnapshot.reportingPeriod,
      },
      if (reportSchemaVersion >= 3)
        'brandingConfiguration': bundle.brandingConfiguration.toJson(),
      if (reportSchemaVersion >= 3)
        'sectionConfiguration': bundle.sectionConfiguration.toJson(),
      'guardPerformance': bundle.guardPerformance
          .map(
            (guard) => <String, Object?>{
              'guardName': guard.guardName,
              'idNumber': guard.idNumber,
              'psiraNumber': guard.psiraNumber,
              'rank': guard.rank,
              'compliancePercentage': double.parse(
                guard.compliancePercentage.toStringAsFixed(6),
              ),
              'escalationsHandled': guard.escalationsHandled,
            },
          )
          .toList(growable: false),
      'patrolPerformance': <String, Object?>{
        'scheduledPatrols': bundle.patrolPerformance.scheduledPatrols,
        'completedPatrols': bundle.patrolPerformance.completedPatrols,
        'missedPatrols': bundle.patrolPerformance.missedPatrols,
        'completionRate': double.parse(
          bundle.patrolPerformance.completionRate.toStringAsFixed(6),
        ),
      },
      'incidentDetails': bundle.incidentDetails
          .map(
            (incident) => <String, Object?>{
              'incidentId': incident.incidentId,
              'riskCategory': incident.riskCategory,
              'detectedAt': incident.detectedAt,
              'slaResult': incident.slaResult,
              'overrideApplied': incident.overrideApplied,
            },
          )
          .toList(growable: false),
      if (reportSchemaVersion >= 2)
        'sceneReview': <String, Object?>{
          'totalReviews': bundle.sceneReview.totalReviews,
          'modelReviews': bundle.sceneReview.modelReviews,
          'metadataFallbackReviews': bundle.sceneReview.metadataFallbackReviews,
          'suppressedActions': bundle.sceneReview.suppressedActions,
          'incidentAlerts': bundle.sceneReview.incidentAlerts,
          'repeatUpdates': bundle.sceneReview.repeatUpdates,
          'escalationCandidates': bundle.sceneReview.escalationCandidates,
          'topPosture': bundle.sceneReview.topPosture,
          'latestActionTaken': bundle.sceneReview.latestActionTaken,
          'latestSuppressedPattern': bundle.sceneReview.latestSuppressedPattern,
          'highlights': bundle.sceneReview.highlights
              .map(
                (highlight) => <String, Object?>{
                  'intelligenceId': highlight.intelligenceId,
                  'detectedAt': highlight.detectedAt,
                  'cameraLabel': highlight.cameraLabel,
                  'sourceLabel': highlight.sourceLabel,
                  'postureLabel': highlight.postureLabel,
                  'decisionLabel': highlight.decisionLabel,
                  'decisionSummary': highlight.decisionSummary,
                  'summary': highlight.summary,
                },
              )
              .toList(growable: false),
        },
      'supervisorAssessment': <String, Object?>{
        'operationalSummary': bundle.supervisorAssessment.operationalSummary,
        'riskTrend': bundle.supervisorAssessment.riskTrend,
        'recommendations': bundle.supervisorAssessment.recommendations,
      },
      'companyAchievements': <String, Object?>{
        'highlights': bundle.companyAchievements.highlights,
      },
      'emergingThreats': <String, Object?>{
        'patternsObserved': bundle.emergingThreats.patternsObserved,
      },
    };

    return jsonEncode(payload);
  }
}
