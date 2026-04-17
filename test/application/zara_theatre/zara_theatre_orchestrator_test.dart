import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/ai/ollama_service.dart';
import 'package:omnix_dashboard/application/zara_theatre/zara_action.dart';
import 'package:omnix_dashboard/application/zara_theatre/zara_action_executor.dart';
import 'package:omnix_dashboard/application/zara_theatre/zara_intent_parser.dart';
import 'package:omnix_dashboard/application/zara_theatre/zara_scenario.dart';
import 'package:omnix_dashboard/application/zara_theatre/zara_theatre_orchestrator.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/incident_closed.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_advisory_recorded.dart';
import 'package:omnix_dashboard/domain/store/event_store.dart';

void main() {
  test(
    'alarm event produces an alarmTriage scenario and writes action logs through completion',
    () async {
      final eventStream = StreamController<List<DispatchEvent>>.broadcast();
      final store = _RecordingEventStore();
      final loggedActions = <String>[];
      final persistedLifecycleStates = <ZaraScenarioLifecycleState>[];

      final orchestrator = ZaraTheatreOrchestrator(
        intentParser: ZaraIntentParser(
          ollamaService: const _AlarmResponseOllamaService(),
        ),
        actionExecutor: ZaraActionExecutor(
          eventStore: store,
          clock: () => DateTime.utc(2026, 4, 17, 10, 5),
        ),
        eventStream: eventStream.stream,
        onActionLogged: (scenario, action, outcome, resultJson) async {
          loggedActions.add('${action.kind.name}:${outcome.name}');
        },
        onScenarioPersisted: (scenario) async {
          persistedLifecycleStates.add(scenario.lifecycleState);
        },
      );

      addTearDown(() async {
        orchestrator.dispose();
        await eventStream.close();
        await store.dispose();
      });

      eventStream.add(<DispatchEvent>[_alarmEvent()]);

      await _waitUntil(() => orchestrator.activeScenario != null);
      await _waitUntil(() {
        final scenario = orchestrator.activeScenario;
        if (scenario == null) {
          return false;
        }
        final checkFootage = scenario.proposedActions.firstWhere(
          (action) => action.kind == ZaraActionKind.checkFootage,
        );
        final checkWeather = scenario.proposedActions.firstWhere(
          (action) => action.kind == ZaraActionKind.checkWeather,
        );
        return checkFootage.state == ZaraActionState.completed &&
            checkWeather.state == ZaraActionState.completed;
      });

      var scenario = orchestrator.activeScenario!;
      expect(scenario.kind, ZaraScenarioKind.alarmTriage);
      expect(
        scenario.lifecycleState,
        ZaraScenarioLifecycleState.awaitingController,
      );

      await orchestrator.submitControllerInput(
        'Stand down dispatch and keep monitoring. Do not send the client message.',
      );

      scenario = orchestrator.activeScenario!;
      final messageAction = scenario.proposedActions.firstWhere(
        (action) => action.kind == ZaraActionKind.draftClientMessage,
      );
      final dispatchAction = scenario.proposedActions.firstWhere(
        (action) => action.kind == ZaraActionKind.standDownDispatch,
      );
      final monitoringAction = scenario.proposedActions.firstWhere(
        (action) => action.kind == ZaraActionKind.continueMonitoring,
      );

      expect(messageAction.state, ZaraActionState.rejected);
      expect(dispatchAction.state, ZaraActionState.awaitingConfirmation);
      expect(monitoringAction.state, ZaraActionState.awaitingConfirmation);

      await orchestrator.confirmAction(dispatchAction.id);
      await _waitUntil(() {
        final current = orchestrator.activeScenario;
        final action = current?.proposedActions.firstWhere(
          (candidate) => candidate.id == dispatchAction.id,
        );
        return action?.state == ZaraActionState.completed;
      });

      await orchestrator.confirmAction(monitoringAction.id);
      await _waitUntil(() {
        return orchestrator.activeScenario?.lifecycleState ==
            ZaraScenarioLifecycleState.complete;
      });

      scenario = orchestrator.activeScenario!;
      expect(scenario.lifecycleState, ZaraScenarioLifecycleState.complete);
      expect(loggedActions, hasLength(5));
      expect(
        loggedActions,
        containsAll(<String>[
          'checkFootage:autoExecuted',
          'checkWeather:autoExecuted',
          'draftClientMessage:rejected',
          'standDownDispatch:approved',
          'continueMonitoring:approved',
        ]),
      );
      expect(store.events.whereType<IncidentClosed>(), hasLength(1));
      expect(
        store.events.whereType<IncidentClosed>().single.dispatchId,
        'ALARM-1',
      );
      expect(
        persistedLifecycleStates,
        contains(ZaraScenarioLifecycleState.complete),
      );
    },
  );
}

class _AlarmResponseOllamaService implements OllamaService {
  const _AlarmResponseOllamaService();

  @override
  bool get isConfigured => true;

  @override
  Future<String?> generate({
    required String systemPrompt,
    required String userPrompt,
    required String model,
  }) async {
    final actionIdsByLabel = <String, String>{};
    final matches = RegExp(
      r'^- ([^:]+): (.+)$',
      multiLine: true,
    ).allMatches(userPrompt);
    for (final match in matches) {
      final actionId = match.group(1)?.trim() ?? '';
      final label = match.group(2)?.trim() ?? '';
      if (actionId.isEmpty || label.isEmpty) {
        continue;
      }
      actionIdsByLabel[label] = actionId;
    }

    return jsonEncode(<String, Object?>{
      'selections': <Map<String, Object?>>[
        <String, Object?>{
          'action_id': actionIdsByLabel['Draft and send client update'],
          'modifier': 'reject',
          'draft_edits': '',
          'clarification': '',
        },
        <String, Object?>{
          'action_id': actionIdsByLabel['Stand down reaction dispatch'],
          'modifier': 'approve',
          'draft_edits': '',
          'clarification': '',
        },
        <String, Object?>{
          'action_id': actionIdsByLabel['Keep monitoring the property'],
          'modifier': 'approve',
          'draft_edits': '',
          'clarification': '',
        },
      ],
      'clarification': '',
    });
  }
}

class _RecordingEventStore implements EventStore {
  final StreamController<List<DispatchEvent>> _controller =
      StreamController<List<DispatchEvent>>.broadcast();
  final List<DispatchEvent> events = <DispatchEvent>[];

  @override
  void append(DispatchEvent event) {
    events.add(event);
    _controller.add(List<DispatchEvent>.unmodifiable(events));
  }

  @override
  List<DispatchEvent> allEvents() => List<DispatchEvent>.unmodifiable(events);

  @override
  Stream<List<DispatchEvent>> watchAllEvents() => _controller.stream;

  Future<void> dispose() async {
    await _controller.close();
  }
}

ListenerAlarmAdvisoryRecorded _alarmEvent() {
  return ListenerAlarmAdvisoryRecorded(
    eventId: 'listener-alarm-advisory-1',
    sequence: 0,
    version: 1,
    occurredAt: DateTime.utc(2026, 4, 17, 9, 30),
    clientId: 'MS',
    regionId: 'region-ms',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    externalAlarmId: 'ALARM-1',
    accountNumber: 'ACC-1',
    partition: 'Perimeter',
    zone: 'Front beam',
    zoneLabel: 'Front beam',
    eventLabel: 'Intrusion alarm',
    dispositionLabel: 'clear',
    summary: 'No threat and no movement detected on property.',
    recommendation: 'High wind could be interfering with the beam.',
    deliveredCount: 0,
    failedCount: 0,
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not met before timeout.');
}
