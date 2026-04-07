import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_scope_guard.dart';
import 'package:omnix_dashboard/domain/authority/onyx_authority_scope.dart';
import 'package:omnix_dashboard/domain/authority/telegram_role_policy.dart';
import 'package:omnix_dashboard/domain/authority/telegram_scope_binding.dart';

void main() {
  test('telegram role policy keeps supervisors below execute authority', () {
    final policy = TelegramRolePolicy.forRole(OnyxAuthorityRole.supervisor);

    expect(policy.allowedActions.contains(OnyxAuthorityAction.read), isTrue);
    expect(policy.allowedActions.contains(OnyxAuthorityAction.propose), isTrue);
    expect(policy.allowedActions.contains(OnyxAuthorityAction.stage), isTrue);
    expect(
      policy.allowedActions.contains(OnyxAuthorityAction.execute),
      isFalse,
    );
  });

  test('telegram role policy keeps guard and client actions identical', () {
    final guardPolicy = TelegramRolePolicy.forRole(OnyxAuthorityRole.guard);
    final clientPolicy = TelegramRolePolicy.forRole(OnyxAuthorityRole.client);

    expect(clientPolicy.allowedActions, guardPolicy.allowedActions);
    expect(clientPolicy.allowedActions, {
      OnyxAuthorityAction.read,
      OnyxAuthorityAction.propose,
    });
  });

  test(
    'scope guard resolves telegram scope through group and user overlap',
    () {
      const guard = OnyxScopeGuard();
      const groupBinding = TelegramScopeBinding(
        telegramGroupId: 'tg-sandton',
        allowedClientIds: {'CLIENT-SANDTON'},
        allowedSiteIds: {'SITE-SANDTON', 'SITE-VALLEE'},
        allowedActions: {
          OnyxAuthorityAction.read,
          OnyxAuthorityAction.propose,
          OnyxAuthorityAction.stage,
        },
      );

      final scope = guard.resolveTelegramScope(
        telegramUserId: 'tg-user-17',
        role: OnyxAuthorityRole.supervisor,
        groupBinding: groupBinding,
        userAllowedClientIds: const {'CLIENT-SANDTON', 'CLIENT-OTHER'},
        userAllowedSiteIds: const {'SITE-SANDTON'},
      );

      expect(scope.principalId, 'tg-user-17');
      expect(scope.sourceLabel, 'telegram:tg-sandton');
      expect(scope.allowedClientIds, {'CLIENT-SANDTON'});
      expect(scope.allowedSiteIds, {'SITE-SANDTON'});
      expect(scope.allowedActions, {
        OnyxAuthorityAction.read,
        OnyxAuthorityAction.propose,
        OnyxAuthorityAction.stage,
      });
    },
  );

  test('scope guard denies cross-site access outside telegram scope', () {
    const guard = OnyxScopeGuard();
    const scope = OnyxAuthorityScope(
      principalId: 'tg-user-17',
      role: OnyxAuthorityRole.supervisor,
      allowedClientIds: {'CLIENT-SANDTON'},
      allowedSiteIds: {'SITE-SANDTON'},
      allowedActions: {
        OnyxAuthorityAction.read,
        OnyxAuthorityAction.propose,
        OnyxAuthorityAction.stage,
      },
      sourceLabel: 'telegram:tg-sandton',
    );

    final decision = guard.validate(
      scope: scope,
      action: OnyxAuthorityAction.read,
      siteId: 'SITE-VALLEE',
    );

    expect(decision.allowed, isFalse);
    expect(
      decision.reason,
      'Restricted access. This scope is not authorized for that site.\n'
      'Try this room instead: "show dispatches today", "check status of Guard001", or "show incidents last night".',
    );
  });

  test('scope guard denies execute when role policy does not allow it', () {
    const guard = OnyxScopeGuard();
    const scope = OnyxAuthorityScope(
      principalId: 'tg-user-17',
      role: OnyxAuthorityRole.guard,
      allowedClientIds: {'CLIENT-SANDTON'},
      allowedSiteIds: {'SITE-SANDTON'},
      allowedActions: {OnyxAuthorityAction.read, OnyxAuthorityAction.propose},
      sourceLabel: 'telegram:tg-sandton',
    );

    final decision = guard.validate(
      scope: scope,
      action: OnyxAuthorityAction.execute,
      siteId: 'SITE-SANDTON',
    );

    expect(decision.allowed, isFalse);
    expect(decision.reason, 'Action execute is not allowed for guard.');
  });
}
