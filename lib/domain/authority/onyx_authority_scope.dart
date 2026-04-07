enum OnyxAuthorityRole { guard, client, supervisor, admin }

enum OnyxAuthorityAction { read, propose, stage, execute }

class OnyxAuthorityScope {
  final String principalId;
  final OnyxAuthorityRole role;
  final Set<String> allowedClientIds;
  final Set<String> allowedSiteIds;
  final Set<OnyxAuthorityAction> allowedActions;
  final String sourceLabel;

  const OnyxAuthorityScope({
    required this.principalId,
    required this.role,
    required this.allowedClientIds,
    required this.allowedSiteIds,
    required this.allowedActions,
    this.sourceLabel = 'direct',
  });

  bool allowsAction(OnyxAuthorityAction action) {
    return allowedActions.contains(action);
  }

  bool allowsClient(String clientId) {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return true;
    }
    return allowedClientIds.contains(normalizedClientId);
  }

  bool allowsSite(String siteId) {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return true;
    }
    return allowedSiteIds.contains(normalizedSiteId);
  }
}
