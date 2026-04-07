import 'onyx_authority_scope.dart';

class TelegramScopeBinding {
  final String telegramGroupId;
  final Set<String> allowedClientIds;
  final Set<String> allowedSiteIds;
  final Set<OnyxAuthorityAction> allowedActions;

  const TelegramScopeBinding({
    required this.telegramGroupId,
    required this.allowedClientIds,
    required this.allowedSiteIds,
    this.allowedActions = const {
      OnyxAuthorityAction.read,
      OnyxAuthorityAction.propose,
    },
  });
}
