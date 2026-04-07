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
    DateTime Function()? clock,
  }) {
    if (!policy.shouldEscalate(item)) {
      return null;
    }

    final nowUtc = (clock ?? DateTime.now).call().toUtc();

    return DecisionCreated(
      eventId: nowUtc.microsecondsSinceEpoch.toString(),
      sequence: 0,
      version: 1,
      occurredAt: nowUtc,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      dispatchId: 'DSP-${item.id}',
    );
  }
}
