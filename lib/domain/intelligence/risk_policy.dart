import 'news_item.dart';

class RiskPolicy {
  final int escalationThreshold;

  const RiskPolicy({
    this.escalationThreshold = 70,
  });

  bool shouldEscalate(NewsItem item) {
    return item.riskScore >= escalationThreshold;
  }
}
