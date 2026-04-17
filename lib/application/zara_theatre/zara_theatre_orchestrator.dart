import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/events/dispatch_event.dart';
import '../../domain/events/listener_alarm_advisory_recorded.dart';
import '../supabase/supabase_service.dart';
import 'zara_action.dart';
import 'zara_action_executor.dart';
import 'zara_intent_parser.dart';
import 'zara_scenario.dart';

typedef ZaraScenarioPersistedCallback =
    Future<void> Function(ZaraScenario scenario);
typedef ZaraActionLoggedCallback =
    Future<void> Function(
      ZaraScenario scenario,
      ZaraAction action,
      ZaraActionExecutionOutcome outcome,
      Map<String, Object?> resultJson,
    );

class ZaraTheatreOrchestrator extends ChangeNotifier {
  final ZaraIntentParser intentParser;
  final ZaraActionExecutor actionExecutor;
  final Stream<List<DispatchEvent>>? eventStream;
  final SupabaseService? supabaseService;
  final String Function()? controllerUserIdProvider;
  final String Function()? orgIdProvider;
  final ZaraScenarioPersistedCallback? onScenarioPersisted;
  final ZaraActionLoggedCallback? onActionLogged;

  final StreamController<ZaraScenario?> _activeScenariosController =
      StreamController<ZaraScenario?>.broadcast();
  final List<ZaraScenario> _activeScenarios = <ZaraScenario>[];
  final Set<String> _handledOriginEventIds = <String>{};

  StreamSubscription<List<DispatchEvent>>? _eventSubscription;

  ZaraTheatreOrchestrator({
    required this.intentParser,
    required this.actionExecutor,
    this.eventStream,
    this.supabaseService,
    this.controllerUserIdProvider,
    this.orgIdProvider,
    this.onScenarioPersisted,
    this.onActionLogged,
  }) {
    _eventSubscription = eventStream?.listen(_handleEvents);
  }

  Stream<ZaraScenario?> get activeScenariosStream =>
      _activeScenariosController.stream;

  List<ZaraScenario> get activeScenarios =>
      List<ZaraScenario>.unmodifiable(_activeScenarios);

  ZaraScenario? get activeScenario =>
      _activeScenarios.isEmpty ? null : _activeScenarios.first;

  void seedEvents(List<DispatchEvent> events) {
    _handleEvents(events);
  }

  void debugSurfaceScenario(ZaraScenario scenario) {
    _activeScenarios
      ..removeWhere((candidate) => candidate.id == scenario.id)
      ..insert(0, scenario);
    _emit();
  }

  Future<void> submitControllerInput(String text) async {
    final scenario = activeScenario;
    if (scenario == null) {
      return;
    }

    final parsingScenario = scenario.copyWith(
      isParsingControllerInput: true,
      clarificationRequest: '',
    );
    _replaceScenario(parsingScenario);
    await _persistScenario(parsingScenario);

    final selections = await intentParser.parse(text, parsingScenario);
    final latestScenario = _scenarioById(parsingScenario.id) ?? parsingScenario;
    final unclear = selections
        .where((selection) {
          return selection.modifier == ZaraActionSelectionModifier.unclear;
        })
        .toList(growable: false);
    if (unclear.isNotEmpty) {
      final clarifiedScenario = latestScenario.copyWith(
        isParsingControllerInput: false,
        clarificationRequest: unclear.first.clarificationRequest,
        lifecycleState: _lifecycleForActions(latestScenario.proposedActions),
      );
      _replaceScenario(clarifiedScenario);
      await _persistScenario(clarifiedScenario);
      return;
    }

    final logFutures = <Future<void>>[];
    final updatedActions = <ZaraAction>[];
    for (final action in latestScenario.proposedActions) {
      if (_isResolvedAction(action) ||
          action.state == ZaraActionState.executing) {
        updatedActions.add(action);
        continue;
      }
      final selection = selections.cast<ZaraActionSelection?>().firstWhere(
        (candidate) => candidate?.actionId == action.id,
        orElse: () => null,
      );
      if (selection == null) {
        updatedActions.add(action);
        continue;
      }
      switch (selection.modifier) {
        case ZaraActionSelectionModifier.approve:
          updatedActions.add(
            action.copyWith(
              state: action.confirmRequired
                  ? ZaraActionState.awaitingConfirmation
                  : ZaraActionState.proposed,
              pendingDraftEdits: '',
            ),
          );
        case ZaraActionSelectionModifier.modify:
          updatedActions.add(
            action.copyWith(
              state: ZaraActionState.awaitingConfirmation,
              pendingDraftEdits: selection.draftEdits,
            ),
          );
        case ZaraActionSelectionModifier.reject:
          final rejectedAction = action.copyWith(
            state: ZaraActionState.rejected,
            pendingDraftEdits: '',
          );
          updatedActions.add(rejectedAction);
          logFutures.add(
            _appendActionLog(
              scenario: latestScenario,
              action: rejectedAction,
              outcome: ZaraActionExecutionOutcome.rejected,
              resultJson: const <String, Object?>{
                'status': 'controller_rejected',
              },
            ),
          );
        case ZaraActionSelectionModifier.unclear:
          updatedActions.add(action);
      }
    }

    final nextScenario = latestScenario.copyWith(
      proposedActions: updatedActions,
      lifecycleState: _lifecycleForActions(updatedActions),
      isParsingControllerInput: false,
      clarificationRequest: '',
    );
    _replaceScenario(nextScenario);
    await _persistScenario(nextScenario);
    if (logFutures.isNotEmpty) {
      await Future.wait(logFutures);
    }
  }

  Future<void> confirmAction(ZaraActionId actionId) async {
    final scenario = activeScenario;
    if (scenario == null) {
      return;
    }
    final action = _actionById(scenario, actionId);
    if (action == null || _isResolvedAction(action)) {
      return;
    }
    await _executeAction(
      scenarioId: scenario.id,
      actionId: actionId,
      executingState: ZaraActionState.executing,
    );
  }

  Future<void> rejectAction(ZaraActionId actionId) async {
    final scenario = activeScenario;
    if (scenario == null) {
      return;
    }
    final action = _actionById(scenario, actionId);
    if (action == null || _isResolvedAction(action)) {
      return;
    }
    final rejectedAction = action.copyWith(
      state: ZaraActionState.rejected,
      pendingDraftEdits: '',
    );
    final updatedScenario = _scenarioWithUpdatedAction(
      scenario: scenario,
      actionId: actionId,
      transformer: (_) => rejectedAction,
    );
    _replaceScenario(updatedScenario);
    await _persistScenario(updatedScenario);
    await _appendActionLog(
      scenario: updatedScenario,
      action: rejectedAction,
      outcome: ZaraActionExecutionOutcome.rejected,
      resultJson: const <String, Object?>{'status': 'controller_rejected'},
    );
  }

  @override
  void dispose() {
    unawaited(_eventSubscription?.cancel());
    unawaited(_activeScenariosController.close());
    super.dispose();
  }

  void _handleEvents(List<DispatchEvent> events) {
    for (final event in events) {
      switch (event) {
        case ListenerAlarmAdvisoryRecorded():
          if (!_handledOriginEventIds.add(event.eventId)) {
            continue;
          }
          final scenario = _buildAlarmTriageScenario(event);
          unawaited(_surfaceScenario(scenario));
        default:
          // TODO: implement non-alarm Zara Theatre scenario rules in later phases.
          continue;
      }
    }
  }

  ZaraScenario _buildAlarmTriageScenario(ListenerAlarmAdvisoryRecorded event) {
    final suspicious = _isSuspiciousDisposition(event);
    final siteLabel = _humanizeSiteId(event.siteId);
    final autoFootageSummary = _footageSummary(event);
    final autoWeatherSummary = _weatherSummary(event);
    final dispatchAction = suspicious
        ? ZaraAction(
            id: ZaraActionId.generate(),
            kind: ZaraActionKind.dispatchReaction,
            label: 'Dispatch reaction as a precaution',
            reversible: false,
            confirmRequired: true,
            payload: ZaraDispatchPayload(
              clientId: event.clientId,
              regionId: event.regionId,
              siteId: event.siteId,
              dispatchId: event.externalAlarmId,
              note: event.recommendation,
            ),
          )
        : ZaraAction(
            id: ZaraActionId.generate(),
            kind: ZaraActionKind.standDownDispatch,
            label: 'Stand down reaction dispatch',
            reversible: false,
            confirmRequired: true,
            payload: ZaraDispatchPayload(
              clientId: event.clientId,
              regionId: event.regionId,
              siteId: event.siteId,
              dispatchId: event.externalAlarmId,
              note: event.recommendation,
            ),
          );
    final clientDraftText = suspicious
        ? 'Control update: We investigated the alarm at $siteLabel. Footage review remains active and Zara is dispatching reaction as a precaution while monitoring continues.'
        : 'Control update: We investigated the alarm at $siteLabel. Footage shows no threat, weather may be contributing to the trigger, and we are continuing to monitor the property.';

    return ZaraScenario(
      id: ZaraScenarioId.generate(),
      kind: ZaraScenarioKind.alarmTriage,
      createdAt: event.occurredAt.toUtc(),
      originEventIds: <String>[event.eventId],
      summary:
          'Alarm at $siteLabel. $autoFootageSummary $autoWeatherSummary ${_decisionPromptForAlarm(event)}',
      proposedActions: <ZaraAction>[
        ZaraAction(
          id: ZaraActionId.generate(),
          kind: ZaraActionKind.checkFootage,
          label: 'Checked footage',
          reversible: true,
          confirmRequired: false,
          payload: ZaraMonitoringPayload(
            siteId: event.siteId,
            detail: event.summary,
          ),
        ),
        ZaraAction(
          id: ZaraActionId.generate(),
          kind: ZaraActionKind.checkWeather,
          label: 'Checked weather',
          reversible: true,
          confirmRequired: false,
          payload: ZaraMonitoringPayload(
            siteId: event.siteId,
            detail: '${event.summary} ${event.recommendation}'.trim(),
          ),
        ),
        ZaraAction(
          id: ZaraActionId.generate(),
          kind: ZaraActionKind.draftClientMessage,
          label: 'Draft and send client update',
          reversible: false,
          confirmRequired: true,
          payload: ZaraClientMessagePayload(
            clientId: event.clientId,
            siteId: event.siteId,
            room: 'Residents',
            incidentReference: event.externalAlarmId,
            draftText: clientDraftText,
            originalDraftText: clientDraftText,
          ),
        ),
        dispatchAction,
        ZaraAction(
          id: ZaraActionId.generate(),
          kind: ZaraActionKind.continueMonitoring,
          label: 'Keep monitoring the property',
          reversible: false,
          confirmRequired: true,
          payload: ZaraMonitoringPayload(
            siteId: event.siteId,
            detail: suspicious
                ? 'Reaction is moving while Zara keeps a live watch on the site.'
                : 'Zara will keep watch on the site after the alarm is stood down.',
          ),
        ),
      ],
      relatedSiteId: event.siteId,
      relatedDispatchIds: <String>[event.externalAlarmId],
      urgency: suspicious
          ? ZaraScenarioUrgency.critical
          : ZaraScenarioUrgency.attention,
      lifecycleState: ZaraScenarioLifecycleState.proposing,
    );
  }

  Future<void> _surfaceScenario(ZaraScenario scenario) async {
    debugSurfaceScenario(scenario);
    await _persistScenario(scenario);
    await _runAutoActions(scenario.id);
  }

  Future<void> _runAutoActions(ZaraScenarioId scenarioId) async {
    final scenario = _scenarioById(scenarioId);
    if (scenario == null) {
      return;
    }
    final autoActionIds = scenario.proposedActions
        .where((action) => action.isAutoExecutable)
        .map((action) => action.id)
        .toList(growable: false);
    for (final actionId in autoActionIds) {
      await _executeAction(
        scenarioId: scenarioId,
        actionId: actionId,
        executingState: ZaraActionState.autoExecuting,
      );
    }
    final settledScenario = _scenarioById(scenarioId);
    if (settledScenario == null) {
      return;
    }
    final normalizedScenario = settledScenario.copyWith(
      lifecycleState: _lifecycleForActions(settledScenario.proposedActions),
    );
    _replaceScenario(normalizedScenario);
    await _persistScenario(normalizedScenario);
  }

  Future<void> _executeAction({
    required ZaraScenarioId scenarioId,
    required ZaraActionId actionId,
    required ZaraActionState executingState,
  }) async {
    final scenario = _scenarioById(scenarioId);
    if (scenario == null) {
      return;
    }
    final action = _actionById(scenario, actionId);
    if (action == null || _isResolvedAction(action)) {
      return;
    }

    final executingScenario = _scenarioWithUpdatedAction(
      scenario: scenario,
      actionId: actionId,
      transformer: (current) => current.copyWith(state: executingState),
      lifecycleState: ZaraScenarioLifecycleState.executing,
    );
    _replaceScenario(executingScenario);
    await _persistScenario(executingScenario);

    final actionForExecution = _actionById(executingScenario, actionId);
    if (actionForExecution == null) {
      return;
    }

    final result = await actionExecutor.execute(
      scenario: executingScenario,
      action: actionForExecution,
      draftOverride: actionForExecution.pendingDraftEdits,
    );
    final completedScenario = _scenarioWithUpdatedAction(
      scenario: executingScenario,
      actionId: actionId,
      transformer: (current) {
        return current.copyWith(
          state: result.success
              ? ZaraActionState.completed
              : ZaraActionState.failed,
          resolutionSummary: result.sideEffectsSummary,
        );
      },
    );
    _replaceScenario(completedScenario);
    await _persistScenario(completedScenario);
    await _appendActionLog(
      scenario: completedScenario,
      action: _actionById(completedScenario, actionId) ?? actionForExecution,
      outcome: result.outcome,
      resultJson: result.resultData,
    );
  }

  ZaraScenario _scenarioWithUpdatedAction({
    required ZaraScenario scenario,
    required ZaraActionId actionId,
    required ZaraAction Function(ZaraAction action) transformer,
    ZaraScenarioLifecycleState? lifecycleState,
  }) {
    final updatedActions = scenario.proposedActions
        .map((action) => action.id == actionId ? transformer(action) : action)
        .toList(growable: false);
    return scenario.copyWith(
      proposedActions: updatedActions,
      lifecycleState: lifecycleState ?? _lifecycleForActions(updatedActions),
    );
  }

  ZaraScenarioLifecycleState _lifecycleForActions(
    Iterable<ZaraAction> actions,
  ) {
    final actionList = actions.toList(growable: false);
    if (actionList.any((action) {
      return action.state == ZaraActionState.executing ||
          action.state == ZaraActionState.autoExecuting;
    })) {
      return ZaraScenarioLifecycleState.executing;
    }
    if (actionList.any((action) {
      return action.state == ZaraActionState.proposed ||
          action.state == ZaraActionState.awaitingConfirmation ||
          action.state == ZaraActionState.failed;
    })) {
      return ZaraScenarioLifecycleState.awaitingController;
    }
    return ZaraScenarioLifecycleState.complete;
  }

  ZaraScenario? _scenarioById(ZaraScenarioId scenarioId) {
    for (final scenario in _activeScenarios) {
      if (scenario.id == scenarioId) {
        return scenario;
      }
    }
    return null;
  }

  ZaraAction? _actionById(ZaraScenario scenario, ZaraActionId actionId) {
    for (final action in scenario.proposedActions) {
      if (action.id == actionId) {
        return action;
      }
    }
    return null;
  }

  bool _isResolvedAction(ZaraAction action) {
    return action.state == ZaraActionState.completed ||
        action.state == ZaraActionState.rejected ||
        action.state == ZaraActionState.failed;
  }

  void _replaceScenario(ZaraScenario scenario) {
    final index = _activeScenarios.indexWhere(
      (candidate) => candidate.id == scenario.id,
    );
    if (index >= 0) {
      _activeScenarios[index] = scenario;
    } else {
      _activeScenarios.insert(0, scenario);
    }
    _emit();
  }

  void _emit() {
    _activeScenariosController.add(activeScenario);
    notifyListeners();
  }

  Future<void> _persistScenario(ZaraScenario scenario) async {
    try {
      final service = supabaseService;
      if (service != null) {
        await service.upsertZaraScenario(
          scenario: scenario,
          controllerUserId: controllerUserIdProvider?.call().trim() ?? '',
          orgId: orgIdProvider?.call().trim() ?? '',
        );
      }
      if (onScenarioPersisted != null) {
        await onScenarioPersisted!(scenario);
      }
    } catch (error, stackTrace) {
      debugPrint('Zara Theatre failed to persist scenario: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _appendActionLog({
    required ZaraScenario scenario,
    required ZaraAction action,
    required ZaraActionExecutionOutcome outcome,
    required Map<String, Object?> resultJson,
  }) async {
    try {
      final service = supabaseService;
      if (service != null) {
        await service.appendZaraActionLog(
          scenario: scenario,
          action: action,
          outcome: outcome,
          resultJson: resultJson,
          orgId: orgIdProvider?.call().trim() ?? '',
        );
      }
      if (onActionLogged != null) {
        await onActionLogged!(scenario, action, outcome, resultJson);
      }
    } catch (error, stackTrace) {
      debugPrint('Zara Theatre failed to append action log: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _isSuspiciousDisposition(ListenerAlarmAdvisoryRecorded event) {
    return event.dispositionLabel.trim().toLowerCase() == 'suspicious';
  }

  String _decisionPromptForAlarm(ListenerAlarmAdvisoryRecorded event) {
    return _isSuspiciousDisposition(event)
        ? 'Would you like me to draft a client update, dispatch reaction, and keep monitoring?'
        : 'Would you like me to draft a client update, stand down reaction, and keep monitoring?';
  }

  String _footageSummary(ListenerAlarmAdvisoryRecorded event) {
    final normalized = event.summary.toLowerCase();
    if (normalized.contains('no threat') ||
        normalized.contains('no movement') ||
        normalized.contains('clear')) {
      return 'I checked footage and saw no threat or movement on property.';
    }
    if (normalized.contains('unavailable') || normalized.contains('unknown')) {
      return 'I checked footage, but visual confirmation is limited right now.';
    }
    return 'I checked footage and do not see an obvious hostile pattern.';
  }

  String _weatherSummary(ListenerAlarmAdvisoryRecorded event) {
    final normalized = '${event.summary} ${event.recommendation}'
        .toLowerCase()
        .trim();
    if (normalized.contains('wind')) {
      return 'Weather shows high wind, which could explain the trigger.';
    }
    if (normalized.contains('storm') || normalized.contains('rain')) {
      return 'Weather conditions could be contributing to the trigger.';
    }
    if (_isSuspiciousDisposition(event)) {
      return 'Weather does not give me a benign explanation yet.';
    }
    return 'Weather does not show a stronger explanation than interference.';
  }

  String _humanizeSiteId(String raw) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^SITE-', caseSensitive: false), '')
        .replaceAll(RegExp(r'[-_]+'), ' ');
    return cleaned
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}
