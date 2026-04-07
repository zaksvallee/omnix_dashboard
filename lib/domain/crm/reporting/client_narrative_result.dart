import 'report_audience.dart';

Map<String, dynamic>? stringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map<String, dynamic>(
    (key, entryValue) => MapEntry(key.toString(), entryValue),
  );
}

class ClientNarrativeResult {
  final String clientId;
  final String month;
  final ReportAudience audience;
  final String executiveHeadline;
  final String executivePerformanceSummary;
  final String executiveSlaSummary;
  final String executiveRiskSummary;
  final String supervisorOperationalSummary;
  final String supervisorRiskTrend;
  final String supervisorRecommendations;
  final List<String> companyAchievements;
  final List<String> emergingThreats;
  final String modelId;
  final DateTime generatedAt;
  final int inputTokens;
  final int outputTokens;

  const ClientNarrativeResult({
    required this.clientId,
    required this.month,
    required this.audience,
    required this.executiveHeadline,
    required this.executivePerformanceSummary,
    required this.executiveSlaSummary,
    required this.executiveRiskSummary,
    required this.supervisorOperationalSummary,
    required this.supervisorRiskTrend,
    required this.supervisorRecommendations,
    required this.companyAchievements,
    required this.emergingThreats,
    required this.modelId,
    required this.generatedAt,
    required this.inputTokens,
    required this.outputTokens,
  });

  factory ClientNarrativeResult.fallback({
    required String clientId,
    required String month,
    required ReportAudience audience,
  }) {
    return ClientNarrativeResult(
      clientId: clientId,
      month: month,
      audience: audience,
      executiveHeadline: '',
      executivePerformanceSummary: '',
      executiveSlaSummary: '',
      executiveRiskSummary: '',
      supervisorOperationalSummary: '',
      supervisorRiskTrend: '',
      supervisorRecommendations: '',
      companyAchievements: const <String>[],
      emergingThreats: const <String>[],
      modelId: 'fallback',
      generatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      inputTokens: 0,
      outputTokens: 0,
    );
  }

  static ClientNarrativeResult? fromClaudeJson(
    Map<String, dynamic> json, {
    required String clientId,
    required String month,
    required ReportAudience audience,
    required String modelId,
    required DateTime generatedAt,
    required int inputTokens,
    required int outputTokens,
  }) {
    final exec = stringKeyedMap(json['executiveSummary']);
    final supervisor = stringKeyedMap(json['supervisorAssessment']);
    final achievements = json['companyAchievements'];
    final threats = json['emergingThreats'];
    if (exec == null ||
        supervisor == null ||
        achievements is! List ||
        threats is! List) {
      return null;
    }

    return ClientNarrativeResult(
      clientId: clientId,
      month: month,
      audience: audience,
      executiveHeadline: exec['headline']?.toString() ?? '',
      executivePerformanceSummary: exec['performanceSummary']?.toString() ?? '',
      executiveSlaSummary: exec['slaSummary']?.toString() ?? '',
      executiveRiskSummary: exec['riskSummary']?.toString() ?? '',
      supervisorOperationalSummary:
          supervisor['operationalSummary']?.toString() ?? '',
      supervisorRiskTrend: supervisor['riskTrend']?.toString() ?? '',
      supervisorRecommendations:
          supervisor['recommendations']?.toString() ?? '',
      companyAchievements: achievements.whereType<String>().toList(
        growable: false,
      ),
      emergingThreats: threats.whereType<String>().toList(growable: false),
      modelId: modelId,
      generatedAt: generatedAt,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );
  }
}
