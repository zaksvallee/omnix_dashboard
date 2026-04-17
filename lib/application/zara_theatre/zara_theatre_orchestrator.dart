import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/events/dispatch_event.dart';
import '../../domain/events/listener_alarm_advisory_recorded.dart';
import 'zara_action.dart';
import 'zara_action_executor.dart';
import 'zara_intent_parser.dart';
import 'zara_scenario.dart';

class ZaraTheatreOrchestrator extends ChangeNotifier {
  final ZaraIntentParser intentParser;
  final ZaraActionExecutor actionExecutor;
  final Stream<List<DispatchEvent>>? eventStream;

  final StreamController<ZaraScenario?> _activeScenariosController =
      StreamController<ZaraScenario?>.broadcast();
  final List<ZaraScenario> _activeScenarios = <ZaraScenario>[];
  final Set<String> _handledOriginEventIds = <String>{};

  StreamSubscription<List<DispatchEvent>>? _eventSubscription;

  ZaraTheatreOrchestrator({
    required this.intentParser,
    required this.actionExecutor,
    this.eventStream,
  }) {
    _eventSubscription = eventStream?.listen(_handleEvents);
  }

  Stream<ZaraScenario?> get activeScenariosStream =>
      _activeScenariosController.stream;

  List<ZaraScenario> get activeScenarios =>
      List<ZaraScenario>.unmodifiable(_activeScenarios);

  ZaraScenario? get activeScenario =>
      _activeScenarios.isEmpty ? null : _activeScenarios.first;

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
    _replaceActiveScenario(
      scenario.copyWith(
        isParsingControllerInput: true,
        clarificationRequest: '',
      ),
    );
    final selections = await intentParser.parse(text, activeScenario!);
    var nextScenario = activeScenario!;
    final unclear = selections
        .where((selection) {
          return selection.modifier == ZaraActionSelectionModifier.unclear;
        })
        .toList(growable: false);
    if (unclear.isNotEmpty) {
      _replaceActiveScenario(
        nextScenario.copyWith(
          isParsingControllerInput: false,
          clarificationRequest: unclear.first.clarificationRequest,
        ),
      );
      return;
    }

    final updatedActions = <ZaraAction>[];
    for (final action in nextScenario.proposedActions) {
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
          updatedActions.add(action.copyWith(state: ZaraActionState.rejected));
        case ZaraActionSelectionModifier.unclear:
          updatedActions.add(action);
      }
    }
    nextScenario = nextScenario.copyWith(
      proposedActions: updatedActions,
      lifecycleState: ZaraScenarioLifecycleState.awaitingController,
      isParsingControllerInput: false,
      clarificationRequest: '',
    );
    _replaceActiveScenario(nextScenario);
  }

  Future<void> confirmAction(ZaraActionId actionId) async {
    final scenario = activeScenario;
    if (scenario == null) {
      return;
    }
    final action = scenario.proposedActions.cast<ZaraAction?>().firstWhere(
      (candidate) => candidate?.id == actionId,
      orElse: () => null,
    );
    if (action == null) {
      return;
    }
    final executingScenario = _updateAction(
      scenario: scenario,
      actionId: actionId,
      transformer: (current) {
        return current.copyWith(state: ZaraActionState.executing);
      },
      lifecycleState: ZaraScenarioLifecycleState.executing,
    );
    final actionForExecution = executingScenario.proposedActions.firstWhere(
      (candidate) => candidate.id == actionId,
    );
    final result = await actionExecutor.execute(
      scenario: executingScenario,
      action: actionForExecution,
      draftOverride: actionForExecution.pendingDraftEdits,
    );
    final completedScenario = _updateAction(
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
      lifecycleState: _resolvedLifecycleState(
        executingScenario,
        actionId,
        result,
      ),
    );
    _replaceActiveScenario(completedScenario);
  }

  Future<void> rejectAction(ZaraActionId actionId) async {
    final scenario = activeScenario;
    if (scenario == null) {
      return;
    }
    final updated = _updateAction(
      scenario: scenario,
      actionId: actionId,
      transformer: (current) {
        return current.copyWith(state: ZaraActionState.rejected);
      },
      lifecycleState: ZaraScenarioLifecycleState.awaitingController,
    );
    _replaceActiveScenario(updated);
  }

  @override
  void dispose() {
    unawaited(_eventSubscription?.cancel());
    unawaited(_activeScenariosController.close());
    super.dispose();
  }

  void _handleEvents(List<DispatchEvent> events) {
    for (final event in events) {
      if (event is! ListenerAlarmAdvisoryRecorded) {
        continue;
      }
      if (!_handledOriginEventIds.add(event.eventId)) {
        continue;
      }
      final scenario = ZaraScenario(
        id: ZaraScenarioId.generate(),
        kind: ZaraScenarioKind.alarmTriage,
        createdAt: event.occurredAt.toUtc(),
        originEventIds: <String>[event.eventId],
        summary:
            'Alarm at ${_humanizeSiteId(event.siteId)}. ${event.summary} ${event.recommendation}'
                .trim(),
        proposedActions: <ZaraAction>[
          ZaraAction(
            id: ZaraActionId.generate(),
            kind: ZaraActionKind.checkFootage,
            label: 'Check footage',
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
            label: 'Check weather conditions',
            reversible: true,
            confirmRequired: false,
            payload: ZaraMonitoringPayload(
              siteId: event.siteId,
              detail: event.dispositionLabel,
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
              draftText:
                  'Control update: We investigated the alarm at ${_humanizeSiteId(event.siteId)}. ${event.summary} We are continuing to monitor and will update you if the posture changes.',
              originalDraftText:
                  'Control update: We investigated the alarm at ${_humanizeSiteId(event.siteId)}. ${event.summary} We are continuing to monitor and will update you if the posture changes.',
            ),
          ),
          ZaraAction(
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
          ),
          ZaraAction(
            id: ZaraActionId.generate(),
            kind: ZaraActionKind.continueMonitoring,
            label: 'Continue monitoring',
            reversible: false,
            confirmRequired: true,
            payload: ZaraMonitoringPayload(
              siteId: event.siteId,
              detail: event.recommendation,
            ),
          ),
        ],
        relatedSiteId: event.siteId,
        relatedDispatchIds: <String>[event.externalAlarmId],
        urgency: event.dispositionLabel.toLowerCase() == 'suspicious'
            ? ZaraScenarioUrgency.critical
            : ZaraScenarioUrgency.attention,
        lifecycleState: ZaraScenarioLifecycleState.proposing,
      );
      debugSurfaceScenario(scenario);
    }
  }

  ZaraScenario _updateAction({
    required ZaraScenario scenario,
    required ZaraActionId actionId,
    required ZaraAction Function(ZaraAction action) transformer,
    required ZaraScenarioLifecycleState lifecycleState,
  }) {
    final updated = scenario.proposedActions
        .map((action) {
          if (action.id != actionId) {
            return action;
          }
          return transformer(action);
        })
        .toList(growable: false);
    return scenario.copyWith(
      proposedActions: updated,
      lifecycleState: lifecycleState,
    );
  }

  ZaraScenarioLifecycleState _resolvedLifecycleState(
    ZaraScenario scenario,
    ZaraActionId actionId,
    ZaraActionResult result,
  ) {
    if (!result.success) {
      return ZaraScenarioLifecycleState.awaitingController;
    }
    final nextActions = scenario.proposedActions.map((action) {
      if (action.id != actionId) {
        return action;
      }
      return action.copyWith(state: ZaraActionState.completed);
    });
    final unresolved = nextActions.any((action) {
      return action.state == ZaraActionState.proposed ||
          action.state == ZaraActionState.awaitingConfirmation ||
          action.state == ZaraActionState.executing;
    });
    return unresolved
        ? ZaraScenarioLifecycleState.awaitingController
        : ZaraScenarioLifecycleState.complete;
  }

  void _replaceActiveScenario(ZaraScenario scenario) {
    if (_activeScenarios.isEmpty) {
      _activeScenarios.add(scenario);
    } else {
      _activeScenarios[0] = scenario;
    }
    _emit();
  }

  void _emit() {
    _activeScenariosController.add(activeScenario);
    notifyListeners();
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
