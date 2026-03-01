import '../incident_event.dart';
import '../incident_enums.dart';
import 'risk_tag.dart';

class IncidentRiskProjection {
  static List<RiskTag> extractTags(List<IncidentEvent> events) {
    final tags = <RiskTag>[];

    for (final event in events) {
      if (event.metadata.containsKey('risk_tag')) {
        tags.add(
          RiskTag(
            tag: event.metadata['risk_tag'] as String,
            weight: event.metadata['weight'] as int,
            addedAt: event.timestamp,
          ),
        );
      }
    }

    return tags;
  }

  static int computeRiskScore(List<RiskTag> tags) {
    return tags.fold(0, (sum, tag) => sum + tag.weight);
  }

  static IncidentSeverity deriveSeverity(int score) {
    if (score >= 80) return IncidentSeverity.critical;
    if (score >= 50) return IncidentSeverity.high;
    if (score >= 20) return IncidentSeverity.medium;
    return IncidentSeverity.low;
  }
}
