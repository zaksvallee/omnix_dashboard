import 'onyx_authority_scope.dart';

class TelegramRolePolicy {
  final OnyxAuthorityRole role;
  final Set<OnyxAuthorityAction> allowedActions;

  const TelegramRolePolicy({required this.role, required this.allowedActions});

  factory TelegramRolePolicy.forRole(OnyxAuthorityRole role) {
    return TelegramRolePolicy(
      role: role,
      allowedActions: switch (role) {
        OnyxAuthorityRole.guard => const {
          OnyxAuthorityAction.read,
          OnyxAuthorityAction.propose,
        },
        OnyxAuthorityRole.client => const {
          OnyxAuthorityAction.read,
          OnyxAuthorityAction.propose,
        },
        OnyxAuthorityRole.supervisor => const {
          OnyxAuthorityAction.read,
          OnyxAuthorityAction.propose,
          OnyxAuthorityAction.stage,
        },
        OnyxAuthorityRole.admin => const {
          OnyxAuthorityAction.read,
          OnyxAuthorityAction.propose,
          OnyxAuthorityAction.stage,
          OnyxAuthorityAction.execute,
        },
      },
    );
  }
}
