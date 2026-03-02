class ClientSnapshot {
  final String clientId;
  final String clientName;
  final String siteName;
  final String slaTier;
  final String reportingPeriod;

  const ClientSnapshot({
    required this.clientId,
    required this.clientName,
    required this.siteName,
    required this.slaTier,
    required this.reportingPeriod,
  });
}

class GuardPerformanceSnapshot {
  final String guardName;
  final String idNumber;
  final String psiraNumber;
  final String rank;
  final double compliancePercentage;
  final int escalationsHandled;

  const GuardPerformanceSnapshot({
    required this.guardName,
    required this.idNumber,
    required this.psiraNumber,
    required this.rank,
    required this.compliancePercentage,
    required this.escalationsHandled,
  });
}

class PatrolPerformanceSnapshot {
  final int scheduledPatrols;
  final int completedPatrols;
  final int missedPatrols;
  final double completionRate;

  const PatrolPerformanceSnapshot({
    required this.scheduledPatrols,
    required this.completedPatrols,
    required this.missedPatrols,
    required this.completionRate,
  });
}

class IncidentDetailSnapshot {
  final String incidentId;
  final String riskCategory;
  final String detectedAt;
  final String slaResult;
  final bool overrideApplied;

  const IncidentDetailSnapshot({
    required this.incidentId,
    required this.riskCategory,
    required this.detectedAt,
    required this.slaResult,
    required this.overrideApplied,
  });
}

class SupervisorAssessment {
  final String operationalSummary;
  final String riskTrend;
  final String recommendations;

  const SupervisorAssessment({
    required this.operationalSummary,
    required this.riskTrend,
    required this.recommendations,
  });
}

class CompanyAchievementsSnapshot {
  final List<String> highlights;

  const CompanyAchievementsSnapshot({
    required this.highlights,
  });
}

class EmergingThreatSnapshot {
  final List<String> patternsObserved;

  const EmergingThreatSnapshot({
    required this.patternsObserved,
  });
}
