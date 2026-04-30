import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/zara/theatre/zara_action.dart';
import 'package:omnix_dashboard/application/zara/theatre/zara_action_executor.dart';
import 'package:omnix_dashboard/application/zara/theatre/zara_scenario.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/incident_closed.dart';
import 'package:omnix_dashboard/domain/store/event_store.dart';

void main() {
  group('ZaraActionExecutor', () {
    test('auto-executes reversible review actions', () async {
      final executor = ZaraActionExecutor();

      final result = await executor.execute(
        scenario: _scenarioFixture(),
        action: ZaraAction(
          id: const ZaraActionId('check-footage'),
          kind: ZaraActionKind.checkFootage,
          label: 'Checked footage',
          reversible: true,
          confirmRequired: false,
          payload: const ZaraMonitoringPayload(
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            detail: 'No threat and no movement detected on property.',
          ),
        ),
      );

      expect(result.success, isTrue);
      expect(result.outcome, ZaraActionExecutionOutcome.autoExecuted);
      expect(result.sideEffectsSummary, contains('no threat detected'));
    });

    test('executes confirm-required continue monitoring action', () async {
      final executor = ZaraActionExecutor();

      final result = await executor.execute(
        scenario: _scenarioFixture(),
        action: ZaraAction(
          id: const ZaraActionId('monitor'),
          kind: ZaraActionKind.continueMonitoring,
          label: 'Keep monitoring the property',
          reversible: false,
          confirmRequired: true,
          payload: const ZaraMonitoringPayload(
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            detail:
                'Zara will keep watch on the site after the alarm is stood down.',
          ),
        ),
      );

      expect(result.success, isTrue);
      expect(result.outcome, ZaraActionExecutionOutcome.approved);
      expect(result.sideEffectsSummary, contains('Monitoring remains active'));
    });

    test(
      'fails draft client message execution without messaging bridge',
      () async {
        final executor = ZaraActionExecutor();

        final result = await executor.execute(
          scenario: _scenarioFixture(),
          action: ZaraAction(
            id: const ZaraActionId('message'),
            kind: ZaraActionKind.draftClientMessage,
            label: 'Draft and send client update',
            reversible: false,
            confirmRequired: true,
            payload: const ZaraClientMessagePayload(
              clientId: 'MS',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              room: 'Residents',
              incidentReference: 'ALARM-1',
              draftText: 'Client draft',
              originalDraftText: 'Client draft',
            ),
          ),
        );

        expect(result.success, isFalse);
        expect(result.outcome, ZaraActionExecutionOutcome.failed);
        expect(result.sideEffectsSummary, contains('messaging bridge'));
      },
    );

    test(
      'stands down dispatch and records the side effect in the event store',
      () async {
        final store = _RecordingEventStore();
        addTearDown(store.dispose);
        final executor = ZaraActionExecutor(
          eventStore: store,
          clock: () => DateTime.utc(2026, 4, 17, 10, 0),
        );

        final result = await executor.execute(
          scenario: _scenarioFixture(),
          action: ZaraAction(
            id: const ZaraActionId('dispatch'),
            kind: ZaraActionKind.standDownDispatch,
            label: 'Stand down reaction dispatch',
            reversible: false,
            confirmRequired: true,
            payload: const ZaraDispatchPayload(
              clientId: 'MS',
              regionId: 'region-ms',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              dispatchId: 'ALARM-1',
            ),
          ),
        );

        expect(result.success, isTrue);
        expect(result.outcome, ZaraActionExecutionOutcome.approved);
        expect(result.resultData['dispatch_id'], 'ALARM-1');
        expect(store.events, hasLength(1));
        expect(store.events.single, isA<IncidentClosed>());
        expect((store.events.single as IncidentClosed).dispatchId, 'ALARM-1');
      },
    );
  });
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

ZaraScenario _scenarioFixture() {
  return ZaraScenario(
    id: const ZaraScenarioId('scenario-1'),
    kind: ZaraScenarioKind.alarmTriage,
    createdAt: DateTime.utc(2026, 4, 17, 9, 0),
    originEventIds: const <String>['listener-alarm-advisory-1'],
    summary: 'Alarm scenario',
    proposedActions: const <ZaraAction>[],
    relatedSiteId: 'SITE-MS-VALLEE-RESIDENCE',
    relatedDispatchIds: <String>['ALARM-1'],
    urgency: ZaraScenarioUrgency.attention,
    lifecycleState: ZaraScenarioLifecycleState.awaitingController,
  );
}
