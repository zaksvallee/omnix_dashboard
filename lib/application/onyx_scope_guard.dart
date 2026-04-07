import '../domain/authority/onyx_authority_scope.dart';
import '../domain/authority/telegram_role_policy.dart';
import '../domain/authority/telegram_scope_binding.dart';

class OnyxScopeGuardDecision {
  final bool allowed;
  final String reason;

  const OnyxScopeGuardDecision({required this.allowed, required this.reason});
}

class OnyxScopeGuard {
  const OnyxScopeGuard();

  OnyxAuthorityScope resolveTelegramScope({
    required String telegramUserId,
    required OnyxAuthorityRole role,
    required TelegramScopeBinding groupBinding,
    required Set<String> userAllowedClientIds,
    required Set<String> userAllowedSiteIds,
  }) {
    final rolePolicy = TelegramRolePolicy.forRole(role);
    return OnyxAuthorityScope(
      principalId: telegramUserId,
      role: role,
      allowedClientIds: _intersect(
        groupBinding.allowedClientIds,
        userAllowedClientIds,
      ),
      allowedSiteIds: _intersect(
        groupBinding.allowedSiteIds,
        userAllowedSiteIds,
      ),
      allowedActions: _intersectActions(
        groupBinding.allowedActions,
        rolePolicy.allowedActions,
      ),
      sourceLabel: 'telegram:${groupBinding.telegramGroupId}',
    );
  }

  OnyxScopeGuardDecision validate({
    required OnyxAuthorityScope scope,
    required OnyxAuthorityAction action,
    String clientId = '',
    String siteId = '',
    String clientLabel = '',
    String siteLabel = '',
    String scopeLabel = 'This scope',
  }) {
    if (!scope.allowsAction(action)) {
      return OnyxScopeGuardDecision(
        allowed: false,
        reason: 'Action ${action.name} is not allowed for ${scope.role.name}.',
      );
    }
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isNotEmpty &&
        !scope.allowsClient(normalizedClientId)) {
      final deniedClientLabel = clientLabel.trim().isEmpty
          ? 'that client'
          : clientLabel.trim();
      return OnyxScopeGuardDecision(
        allowed: false,
        reason:
            'Restricted access. $scopeLabel is not authorized for $deniedClientLabel.\n'
            '${_restrictedAccessGuidance(scope.role)}',
      );
    }
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isNotEmpty && !scope.allowsSite(normalizedSiteId)) {
      final deniedSiteLabel = siteLabel.trim().isEmpty
          ? 'that site'
          : siteLabel.trim();
      return OnyxScopeGuardDecision(
        allowed: false,
        reason:
            'Restricted access. $scopeLabel is not authorized for $deniedSiteLabel.\n'
            '${_restrictedAccessGuidance(scope.role)}',
      );
    }
    return const OnyxScopeGuardDecision(allowed: true, reason: 'Allowed.');
  }

  String _restrictedAccessGuidance(OnyxAuthorityRole role) {
    return switch (role) {
      OnyxAuthorityRole.client =>
        'Try this room instead: "check cameras", "give me an update", or "what changed tonight".',
      OnyxAuthorityRole.supervisor =>
        'Try this room instead: "show dispatches today", "check status of Guard001", or "show incidents last night".',
      OnyxAuthorityRole.admin =>
        'Try: "check the system", "show dispatches today", or "show unresolved incidents".',
      OnyxAuthorityRole.guard =>
        'Try: "show dispatches today" or "show incidents last night".',
    };
  }

  Set<String> _intersect(Set<String> primary, Set<String> secondary) {
    return primary.intersection(secondary);
  }

  Set<OnyxAuthorityAction> _intersectActions(
    Set<OnyxAuthorityAction> primary,
    Set<OnyxAuthorityAction> secondary,
  ) {
    return primary.intersection(secondary);
  }
}
