import '../intelligence/news_item.dart';

class RiskPolicy {
  final int threshold;

  const RiskPolicy({this.threshold = 70});

  bool shouldEscalate(NewsItem item) {
    return item.riskScore >= threshold;
  }
}
