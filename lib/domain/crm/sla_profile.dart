class SLAProfile {
  final String slaId;
  final String clientId;

  final int lowMinutes;
  final int mediumMinutes;
  final int highMinutes;
  final int criticalMinutes;

  final String createdAt;

  const SLAProfile({
    required this.slaId,
    required this.clientId,
    required this.lowMinutes,
    required this.mediumMinutes,
    required this.highMinutes,
    required this.criticalMinutes,
    required this.createdAt,
  });
}
