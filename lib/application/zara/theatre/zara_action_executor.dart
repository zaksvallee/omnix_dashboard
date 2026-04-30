import '../../client_messaging_bridge_repository.dart';
import '../../dispatch_application_service.dart';
import '../../telegram_bridge_service.dart';
import '../../../domain/events/incident_closed.dart';
import '../../../domain/store/event_store.dart';
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
  final DispatchApplicationService? Function()? dispatchServiceProvider;
  final EventStore? Function()? eventStoreProvider;
  final TelegramBridgeService? Function()? telegramBridgeServiceProvider;
  final SupabaseClientMessagingBridgeRepository? Function()?
  messagingBridgeRepositoryProvider;
  final DateTime Function() clock;

  ZaraActionExecutor({
    this.dispatchService,
    this.eventStore,
    this.telegramBridgeService,
    this.messagingBridgeRepository,
    this.dispatchServiceProvider,
    this.eventStoreProvider,
    this.telegramBridgeServiceProvider,
    this.messagingBridgeRepositoryProvider,
    this.clock = DateTime.now,
  });

  DispatchApplicationService? get _dispatchService {
    return dispatchServiceProvider?.call() ?? dispatchService;
  }

  EventStore? get _eventStore {
    return eventStoreProvider?.call() ?? eventStore;
  }

  TelegramBridgeService? get _telegramBridgeService {
    return telegramBridgeServiceProvider?.call() ?? telegramBridgeService;
  }

  SupabaseClientMessagingBridgeRepository? get _messagingBridgeRepository {
    return messagingBridgeRepositoryProvider?.call() ??
        messagingBridgeRepository;
  }

  Future<ZaraActionResult> execute({
    required ZaraScenario scenario,
    required ZaraAction action,
    String draftOverride = '',
  }) async {
    switch (action.kind) {
      case ZaraActionKind.checkFootage:
      case ZaraActionKind.checkWeather:
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.autoExecuted,
          success: true,
          sideEffectsSummary: _autoResolutionSummary(action),
          resultData: action.payload.toJson(),
        );
      case ZaraActionKind.continueMonitoring:
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.approved,
          success: true,
          sideEffectsSummary: _continueMonitoringSummary(action),
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
    final repository = _messagingBridgeRepository;
    final telegram = _telegramBridgeService;
    if (repository == null || telegram == null) {
      return ZaraActionResult(
        actionId: action.id,
        outcome: ZaraActionExecutionOutcome.failed,
        success: false,
        sideEffectsSummary:
            'Client message could not be sent because the messaging bridge is unavailable.',
      );
    }
    final targets = await repository.readActiveTelegramTargets(
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
    final result = await telegram.sendMessages(
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
    final dispatch = _dispatchService;
    if (payload is! ZaraDispatchPayload || dispatch == null) {
      return ZaraActionResult(
        actionId: action.id,
        outcome: ZaraActionExecutionOutcome.failed,
        success: false,
        sideEffectsSummary:
            'Reaction dispatch could not run because the dispatch service is unavailable.',
      );
    }
    await dispatch.execute(
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
    final store = _eventStore;
    if (payload is! ZaraDispatchPayload || store == null) {
      return ZaraActionResult(
        actionId: action.id,
        outcome: ZaraActionExecutionOutcome.failed,
        success: false,
        sideEffectsSummary:
            'Dispatch stand-down could not run because the event store is unavailable.',
      );
    }
    store.append(
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

  String _autoResolutionSummary(ZaraAction action) {
    final payload = action.payload;
    final detail = payload is ZaraMonitoringPayload
        ? payload.detail.trim()
        : '';
    return switch (action.kind) {
      ZaraActionKind.checkFootage => _footageSummary(detail),
      ZaraActionKind.checkWeather => _weatherSummary(detail),
      _ => action.label,
    };
  }

  String _continueMonitoringSummary(ZaraAction action) {
    final payload = action.payload;
    if (payload is ZaraMonitoringPayload && payload.detail.trim().isNotEmpty) {
      return 'Monitoring remains active. ${payload.detail.trim()}';
    }
    return 'Monitoring remains active and Zara will keep watch on the site.';
  }

  String _footageSummary(String detail) {
    final normalized = detail.toLowerCase();
    if (normalized.contains('no threat') ||
        normalized.contains('no movement') ||
        normalized.contains('clear')) {
      return 'Checked footage — no threat detected on property.';
    }
    if (normalized.contains('unknown') || normalized.contains('unavailable')) {
      return 'Checked footage — visual confirmation is limited, so Zara is keeping the alarm warm.';
    }
    return 'Checked footage — no obvious hostile activity is visible.';
  }

  String _weatherSummary(String detail) {
    final normalized = detail.toLowerCase();
    if (normalized.contains('wind')) {
      return 'Checked weather — high wind could be contributing to the trigger.';
    }
    if (normalized.contains('storm') ||
        normalized.contains('rain') ||
        normalized.contains('weather')) {
      return 'Checked weather — current conditions could explain the alarm trigger.';
    }
    return 'Checked weather — no clear environmental trigger is standing out.';
  }
}
