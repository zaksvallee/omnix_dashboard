import '../client_messaging_bridge_repository.dart';
import '../dispatch_application_service.dart';
import '../telegram_bridge_service.dart';
import '../../domain/events/incident_closed.dart';
import '../../domain/store/event_store.dart';
import 'zara_action.dart';
import 'zara_scenario.dart';

enum ZaraActionExecutionOutcome {
  autoExecuted,
  approved,
  modified,
  rejected,
  failed,
  timedOut,
}

class ZaraActionResult {
  final ZaraActionId actionId;
  final ZaraActionExecutionOutcome outcome;
  final bool success;
  final String sideEffectsSummary;
  final Map<String, Object?> resultData;

  const ZaraActionResult({
    required this.actionId,
    required this.outcome,
    required this.success,
    required this.sideEffectsSummary,
    this.resultData = const <String, Object?>{},
  });
}

class ZaraActionExecutor {
  final DispatchApplicationService? dispatchService;
  final EventStore? eventStore;
  final TelegramBridgeService? telegramBridgeService;
  final SupabaseClientMessagingBridgeRepository? messagingBridgeRepository;
  final DateTime Function() clock;

  const ZaraActionExecutor({
    this.dispatchService,
    this.eventStore,
    this.telegramBridgeService,
    this.messagingBridgeRepository,
    this.clock = DateTime.now,
  });

  Future<ZaraActionResult> execute({
    required ZaraScenario scenario,
    required ZaraAction action,
    String draftOverride = '',
  }) async {
    switch (action.kind) {
      case ZaraActionKind.checkFootage:
      case ZaraActionKind.checkWeather:
      case ZaraActionKind.continueMonitoring:
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.autoExecuted,
          success: true,
          sideEffectsSummary: action.resolutionSummary.isEmpty
              ? action.label
              : action.resolutionSummary,
          resultData: action.payload.toJson(),
        );
      case ZaraActionKind.draftClientMessage:
        return _sendClientMessage(action: action, draftOverride: draftOverride);
      case ZaraActionKind.dispatchReaction:
        return _dispatchReaction(action);
      case ZaraActionKind.standDownDispatch:
        return _standDownDispatch(action);
      case ZaraActionKind.logOB:
      case ZaraActionKind.issueGuardWarning:
      case ZaraActionKind.escalateSupervisor:
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.failed,
          success: false,
          sideEffectsSummary:
              'TODO: ${action.kind.name} execution is staged for a later phase.',
          resultData: <String, Object?>{
            'scenario_id': scenario.id.value,
            'action_kind': action.kind.name,
          },
        );
    }
  }

  Future<ZaraActionResult> _sendClientMessage({
    required ZaraAction action,
    required String draftOverride,
  }) async {
    final payload = action.payload;
    if (payload is! ZaraClientMessagePayload) {
      return ZaraActionResult(
        actionId: action.id,
        outcome: ZaraActionExecutionOutcome.failed,
        success: false,
        sideEffectsSummary: 'Invalid client message payload.',
      );
    }
    if (messagingBridgeRepository == null || telegramBridgeService == null) {
      return ZaraActionResult(
        actionId: action.id,
        outcome: ZaraActionExecutionOutcome.failed,
        success: false,
        sideEffectsSummary:
            'Client message could not be sent because the messaging bridge is unavailable.',
      );
    }
    final targets = await messagingBridgeRepository!.readActiveTelegramTargets(
      clientId: payload.clientId,
      siteId: payload.siteId,
    );
    if (targets.isEmpty) {
      return ZaraActionResult(
        actionId: action.id,
        outcome: ZaraActionExecutionOutcome.failed,
        success: false,
        sideEffectsSummary:
            'No Telegram bridge targets are configured for ${payload.siteId}.',
      );
    }
    final text = draftOverride.trim().isNotEmpty
        ? draftOverride.trim()
        : payload.draftText.trim();
    final result = await telegramBridgeService!.sendMessages(
      messages: [
        for (final target in targets)
          TelegramBridgeMessage(
            messageKey: 'zara-theatre-${action.id.value}-${target.endpointId}',
            chatId: target.chatId,
            messageThreadId: target.threadId,
            text: text,
            source: TelegramBridgeMessageSource.system,
            audience: TelegramBridgeMessageAudience.client,
            controllerAuthored: false,
            approvalGranted: true,
          ),
      ],
    );
    final success = result.sentCount > 0 && result.failedCount == 0;
    return ZaraActionResult(
      actionId: action.id,
      outcome: draftOverride.trim().isNotEmpty
          ? ZaraActionExecutionOutcome.modified
          : ZaraActionExecutionOutcome.approved,
      success: success,
      sideEffectsSummary: success
          ? 'Client message delivered to ${result.sentCount} Telegram target${result.sentCount == 1 ? '' : 's'}.'
          : 'Client message delivery failed.',
      resultData: <String, Object?>{
        'sent_count': result.sentCount,
        'failed_count': result.failedCount,
        'message_text': text,
      },
    );
  }

  Future<ZaraActionResult> _dispatchReaction(ZaraAction action) async {
    final payload = action.payload;
    if (payload is! ZaraDispatchPayload || dispatchService == null) {
      return ZaraActionResult(
        actionId: action.id,
        outcome: ZaraActionExecutionOutcome.failed,
        success: false,
        sideEffectsSummary:
            'Reaction dispatch could not run because the dispatch service is unavailable.',
      );
    }
    await dispatchService!.execute(
      clientId: payload.clientId,
      regionId: payload.regionId,
      siteId: payload.siteId,
      dispatchId: payload.dispatchId,
    );
    return ZaraActionResult(
      actionId: action.id,
      outcome: ZaraActionExecutionOutcome.approved,
      success: true,
      sideEffectsSummary: 'Reaction dispatch ${payload.dispatchId} executed.',
      resultData: payload.toJson(),
    );
  }

  Future<ZaraActionResult> _standDownDispatch(ZaraAction action) async {
    final payload = action.payload;
    if (payload is! ZaraDispatchPayload || eventStore == null) {
      return ZaraActionResult(
        actionId: action.id,
        outcome: ZaraActionExecutionOutcome.failed,
        success: false,
        sideEffectsSummary:
            'Dispatch stand-down could not run because the event store is unavailable.',
      );
    }
    eventStore!.append(
      IncidentClosed(
        eventId:
            'zara-stand-down-${payload.dispatchId}-${clock().toUtc().microsecondsSinceEpoch}',
        sequence: 0,
        version: 1,
        occurredAt: clock().toUtc(),
        dispatchId: payload.dispatchId,
        resolutionType: 'stood_down',
        clientId: payload.clientId,
        regionId: payload.regionId,
        siteId: payload.siteId,
      ),
    );
    return ZaraActionResult(
      actionId: action.id,
      outcome: ZaraActionExecutionOutcome.approved,
      success: true,
      sideEffectsSummary: 'Dispatch ${payload.dispatchId} stood down.',
      resultData: payload.toJson(),
    );
  }
}
