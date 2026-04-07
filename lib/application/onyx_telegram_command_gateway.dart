import '../domain/authority/onyx_authority_scope.dart';
import '../domain/authority/onyx_command_intent.dart';
import '../domain/authority/telegram_scope_binding.dart';
import 'onyx_command_parser.dart';
import 'onyx_scope_guard.dart';

class OnyxTelegramCommandRequest {
  final String telegramUserId;
  final String telegramGroupId;
  final OnyxAuthorityRole role;
  final String prompt;
  final TelegramScopeBinding groupBinding;
  final Set<String> userAllowedClientIds;
  final Set<String> userAllowedSiteIds;
  final String requestedClientId;
  final String requestedSiteId;
  final String requestedClientLabel;
  final String requestedSiteLabel;
  final String? replyToText;
  final List<String> recentThreadContextTexts;

  const OnyxTelegramCommandRequest({
    required this.telegramUserId,
    required this.telegramGroupId,
    required this.role,
    required this.prompt,
    required this.groupBinding,
    required this.userAllowedClientIds,
    required this.userAllowedSiteIds,
    this.requestedClientId = '',
    this.requestedSiteId = '',
    this.requestedClientLabel = '',
    this.requestedSiteLabel = '',
    this.replyToText,
    this.recentThreadContextTexts = const <String>[],
  });
}

class OnyxTelegramCommandGatewayResult {
  final bool allowed;
  final OnyxParsedCommand parsedCommand;
  final OnyxAuthorityScope scope;
  final OnyxAuthorityAction requiredAction;
  final String decisionMessage;

  const OnyxTelegramCommandGatewayResult({
    required this.allowed,
    required this.parsedCommand,
    required this.scope,
    required this.requiredAction,
    required this.decisionMessage,
  });
}

class OnyxTelegramCommandGateway {
  final OnyxCommandParser parser;
  final OnyxScopeGuard scopeGuard;

  const OnyxTelegramCommandGateway({
    this.parser = const OnyxCommandParser(),
    this.scopeGuard = const OnyxScopeGuard(),
  });

  OnyxTelegramCommandGatewayResult route({
    required OnyxTelegramCommandRequest request,
  }) {
    final parsedCommand = parser.parse(request.prompt);
    final scope = scopeGuard.resolveTelegramScope(
      telegramUserId: request.telegramUserId,
      role: request.role,
      groupBinding: request.groupBinding,
      userAllowedClientIds: request.userAllowedClientIds,
      userAllowedSiteIds: request.userAllowedSiteIds,
    );
    final requiredAction = _requiredActionForIntent(parsedCommand.intent);

    if (request.groupBinding.telegramGroupId.trim() !=
        request.telegramGroupId.trim()) {
      return OnyxTelegramCommandGatewayResult(
        allowed: false,
        parsedCommand: parsedCommand,
        scope: scope,
        requiredAction: requiredAction,
        decisionMessage:
            'Restricted access. This Telegram group is not authorized for this request.\n'
            '${_wrongGroupGuidance(request.role)}',
      );
    }

    final decision = scopeGuard.validate(
      scope: scope,
      action: requiredAction,
      clientId: request.requestedClientId,
      siteId: request.requestedSiteId,
      clientLabel: request.requestedClientLabel,
      siteLabel: request.requestedSiteLabel,
      scopeLabel: 'This Telegram group',
    );

    return OnyxTelegramCommandGatewayResult(
      allowed: decision.allowed,
      parsedCommand: parsedCommand,
      scope: scope,
      requiredAction: requiredAction,
      decisionMessage: decision.reason,
    );
  }

  OnyxAuthorityAction _requiredActionForIntent(OnyxCommandIntent intent) {
    return switch (intent) {
      OnyxCommandIntent.draftClientUpdate => OnyxAuthorityAction.stage,
      OnyxCommandIntent.triageNextMove ||
      OnyxCommandIntent.patrolReportLookup ||
      OnyxCommandIntent.guardStatusLookup ||
      OnyxCommandIntent.summarizeIncident ||
      OnyxCommandIntent.showUnresolvedIncidents ||
      OnyxCommandIntent.showSiteMostAlertsThisWeek ||
      OnyxCommandIntent.showDispatchesToday ||
      OnyxCommandIntent.showIncidentsLastNight => OnyxAuthorityAction.read,
    };
  }

  String _wrongGroupGuidance(OnyxAuthorityRole role) {
    return switch (role) {
      OnyxAuthorityRole.client =>
        'Stay in this room and try: "check cameras", "give me an update", or "what changed tonight".',
      OnyxAuthorityRole.supervisor =>
        'Stay in this room and try: "show dispatches today", "check status of Guard001", or "show incidents last night".',
      OnyxAuthorityRole.admin =>
        'Stay in this room and try: "check the system", "show dispatches today", or "show unresolved incidents".',
      OnyxAuthorityRole.guard =>
        'Stay in this room and try: "show dispatches today" or "show incidents last night".',
    };
  }
}
