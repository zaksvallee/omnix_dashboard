import 'crm_event.dart';
import 'sla_tier.dart';

class SLATierProjection {
  static SLATier? rebuild({
    required String clientId,
    required List<CRMEvent> events,
  }) {
    SLATier? tier;

    for (final event in events) {
      if (event.aggregateId != clientId) continue;

      if (event.type == CRMEventType.slaTierAssigned) {
        final tierName = event.payload['tier'] as String?;
        if (tierName != null) {
          tier = SLATier.values
              .firstWhere((t) => t.name == tierName);
        }
      }
    }

    return tier;
  }
}
