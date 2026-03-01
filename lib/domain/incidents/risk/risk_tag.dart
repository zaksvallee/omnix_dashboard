class RiskTag {
  final String tag;
  final int weight; // severity multiplier contribution
  final String addedAt;

  const RiskTag({
    required this.tag,
    required this.weight,
    required this.addedAt,
  });
}
