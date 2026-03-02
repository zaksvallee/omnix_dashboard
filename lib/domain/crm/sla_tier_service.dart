import 'crm_event.dart';
import 'sla_tier.dart';

class SLATierService {
  static CRMEvent assignTier({
    required String clientId,
    required SLATier tier,
    required String operatorId,
  }) {
    return CRMEvent(
      eventId:
          'CRM-SLA-TIER-$clientId-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      aggregateId: clientId,
      type: CRMEventType.slaTierAssigned,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      payload: {
        'clientId': clientId,
        'tier': tier.name,
        'operatorId': operatorId,
      },
    );
  }
}
