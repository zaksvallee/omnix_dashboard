class OperatorContext {
  final String operatorId;
  final Set<String> allowedRegions;
  final Set<String> allowedSites;

  const OperatorContext({
    required this.operatorId,
    required this.allowedRegions,
    required this.allowedSites,
  });

  bool canExecute({
    required String regionId,
    required String siteId,
  }) {
    return allowedRegions.contains(regionId) &&
           allowedSites.contains(siteId);
  }
}
