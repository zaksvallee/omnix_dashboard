import '../events/decision_created.dart';
import 'news_item.dart';
import 'risk_policy.dart';

class DecisionService {
  final RiskPolicy policy;

  const DecisionService(this.policy);

  DecisionCreated? evaluate(
    NewsItem item, {
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    if (!policy.shouldEscalate(item)) {
      return null;
    }

    return DecisionCreated(
      eventId: DateTime.now().microsecondsSinceEpoch.toString(),
      sequence: 0,
      version: 1,
      occurredAt: DateTime.now().toUtc(),
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      dispatchId: 'DSP-${item.id}',
    );
  }
}
