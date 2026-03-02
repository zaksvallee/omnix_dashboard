class SLAProfile {
  final String slaId;
  final String clientId;

  final int lowMinutes;
  final int mediumMinutes;
  final int highMinutes;
  final int criticalMinutes;

  final double lowWeight;
  final double mediumWeight;
  final double highWeight;
  final double criticalWeight;

  final String createdAt;

  const SLAProfile({
    required this.slaId,
    required this.clientId,
    required this.lowMinutes,
    required this.mediumMinutes,
    required this.highMinutes,
    required this.criticalMinutes,
    this.lowWeight = 1.0,
    this.mediumWeight = 2.0,
    this.highWeight = 3.0,
    this.criticalWeight = 5.0,
    required this.createdAt,
  });
}
