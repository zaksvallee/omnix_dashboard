import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_telegram_command_gateway.dart';
import 'package:omnix_dashboard/domain/authority/onyx_authority_scope.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_intent.dart';
import 'package:omnix_dashboard/domain/authority/telegram_scope_binding.dart';

void main() {
  test(
    'telegram gateway routes authorized scoped read commands end to end',
    () {
      const gateway = OnyxTelegramCommandGateway();
      const binding = TelegramScopeBinding(
        telegramGroupId: 'tg-sandton',
        allowedClientIds: {'CLIENT-SANDTON'},
        allowedSiteIds: {'SITE-SANDTON'},
        allowedActions: {
          OnyxAuthorityAction.read,
          OnyxAuthorityAction.propose,
          OnyxAuthorityAction.stage,
        },
      );

      final result = gateway.route(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-user-17',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.supervisor,
          prompt: 'Show unresolved incidents for Sandton Estate',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
      );

      expect(result.allowed, isTrue);
      expect(
        result.parsedCommand.intent,
        OnyxCommandIntent.showUnresolvedIncidents,
      );
      expect(result.requiredAction, OnyxAuthorityAction.read);
      expect(result.decisionMessage, 'Allowed.');
    },
  );

  test(
    'telegram gateway routes authorized staged draft commands end to end',
    () {
      const gateway = OnyxTelegramCommandGateway();
      const binding = TelegramScopeBinding(
        telegramGroupId: 'tg-sandton',
        allowedClientIds: {'CLIENT-SANDTON'},
        allowedSiteIds: {'SITE-SANDTON'},
        allowedActions: {
          OnyxAuthorityAction.read,
          OnyxAuthorityAction.propose,
          OnyxAuthorityAction.stage,
        },
      );

      final result = gateway.route(
        request: const OnyxTelegramCommandRequest(
          telegramUserId: 'tg-supervisor-17',
          telegramGroupId: 'tg-sandton',
          role: OnyxAuthorityRole.supervisor,
          prompt: 'Draft a client update for Sandton Estate',
          groupBinding: binding,
          userAllowedClientIds: {'CLIENT-SANDTON'},
          userAllowedSiteIds: {'SITE-SANDTON'},
          requestedClientId: 'CLIENT-SANDTON',
          requestedSiteId: 'SITE-SANDTON',
          requestedSiteLabel: 'Sandton Estate',
        ),
      );

      expect(result.allowed, isTrue);
      expect(result.parsedCommand.intent, OnyxCommandIntent.draftClientUpdate);
      expect(result.requiredAction, OnyxAuthorityAction.stage);
      expect(result.decisionMessage, 'Allowed.');
    },
  );

  test('telegram gateway denies scope mismatch route end to end', () {
    const gateway = OnyxTelegramCommandGateway();
    const binding = TelegramScopeBinding(
      telegramGroupId: 'tg-sandton',
      allowedClientIds: {'CLIENT-SANDTON'},
      allowedSiteIds: {'SITE-SANDTON'},
    );

    final result = gateway.route(
      request: const OnyxTelegramCommandRequest(
        telegramUserId: 'tg-user-17',
        telegramGroupId: 'tg-sandton',
        role: OnyxAuthorityRole.supervisor,
        prompt: 'Show Vallee Residence incidents',
        groupBinding: binding,
        userAllowedClientIds: {'CLIENT-SANDTON'},
        userAllowedSiteIds: {'SITE-SANDTON', 'SITE-VALLEE'},
        requestedClientId: 'CLIENT-SANDTON',
        requestedSiteId: 'SITE-VALLEE',
        requestedSiteLabel: 'Vallee Residence',
      ),
    );

    expect(result.allowed, isFalse);
    expect(
      result.decisionMessage,
      'Restricted access. This Telegram group is not authorized for Vallee Residence.\n'
      'Try this room instead: "show dispatches today", "check status of Guard001", or "show incidents last night".',
    );
  });

  test('telegram gateway denies unauthorized staged route end to end', () {
    const gateway = OnyxTelegramCommandGateway();
    const binding = TelegramScopeBinding(
      telegramGroupId: 'tg-sandton',
      allowedClientIds: {'CLIENT-SANDTON'},
      allowedSiteIds: {'SITE-SANDTON'},
      allowedActions: {
        OnyxAuthorityAction.read,
        OnyxAuthorityAction.propose,
        OnyxAuthorityAction.stage,
      },
    );

    final result = gateway.route(
      request: const OnyxTelegramCommandRequest(
        telegramUserId: 'tg-guard-2',
        telegramGroupId: 'tg-sandton',
        role: OnyxAuthorityRole.guard,
        prompt: 'Draft a client update for Sandton Estate',
        groupBinding: binding,
        userAllowedClientIds: {'CLIENT-SANDTON'},
        userAllowedSiteIds: {'SITE-SANDTON'},
        requestedClientId: 'CLIENT-SANDTON',
        requestedSiteId: 'SITE-SANDTON',
        requestedSiteLabel: 'Sandton Estate',
      ),
    );

    expect(result.allowed, isFalse);
    expect(result.parsedCommand.intent, OnyxCommandIntent.draftClientUpdate);
    expect(result.requiredAction, OnyxAuthorityAction.stage);
    expect(result.decisionMessage, 'Action stage is not allowed for guard.');
  });

  test('telegram gateway denies requests from the wrong group binding', () {
    const gateway = OnyxTelegramCommandGateway();
    const binding = TelegramScopeBinding(
      telegramGroupId: 'tg-sandton',
      allowedClientIds: {'CLIENT-SANDTON'},
      allowedSiteIds: {'SITE-SANDTON'},
    );

    final result = gateway.route(
      request: const OnyxTelegramCommandRequest(
        telegramUserId: 'tg-user-17',
        telegramGroupId: 'tg-vallee',
        role: OnyxAuthorityRole.supervisor,
        prompt: 'Show unresolved incidents',
        groupBinding: binding,
        userAllowedClientIds: {'CLIENT-SANDTON'},
        userAllowedSiteIds: {'SITE-SANDTON'},
      ),
    );

    expect(result.allowed, isFalse);
    expect(
      result.decisionMessage,
      'Restricted access. This Telegram group is not authorized for this request.\n'
      'Stay in this room and try: "show dispatches today", "check status of Guard001", or "show incidents last night".',
    );
  });
}
