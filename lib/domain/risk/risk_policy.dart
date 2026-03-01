import '../intelligence/news_item.dart';

class RiskPolicy {
  final int escalationThreshold;

  const RiskPolicy({
    required this.escalationThreshold,
  });

  bool shouldEscalate(NewsItem item) {
    return item.riskScore >= escalationThreshold;
  }
}
