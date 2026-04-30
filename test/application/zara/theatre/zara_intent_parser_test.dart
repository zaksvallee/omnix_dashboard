import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/ai/ollama_service.dart';
import 'package:omnix_dashboard/application/zara/theatre/zara_action.dart';
import 'package:omnix_dashboard/application/zara/theatre/zara_intent_parser.dart';
import 'package:omnix_dashboard/application/zara/theatre/zara_scenario.dart';

void main() {
  group('ZaraIntentParser', () {
    test('parses explicit approval', () async {
      final parser = ZaraIntentParser(
        ollamaService: _CannedOllamaService(
          responsesByControllerText: <String, String>{
            'Yes, do it.': _selectionJson(<Map<String, String>>[
              <String, String>{'action_id': 'message', 'modifier': 'approve'},
            ]),
          },
        ),
      );

      final selections = await parser.parse('Yes, do it.', _scenarioFixture());

      expect(selections, hasLength(1));
      expect(selections.single.actionId, const ZaraActionId('message'));
      expect(selections.single.modifier, ZaraActionSelectionModifier.approve);
    });

    test('parses explicit rejection', () async {
      final parser = ZaraIntentParser(
        ollamaService: _CannedOllamaService(
          responsesByControllerText: <String, String>{
            'No, cancel the dispatch.': _selectionJson(<Map<String, String>>[
              <String, String>{'action_id': 'dispatch', 'modifier': 'reject'},
            ]),
          },
        ),
      );

      final selections = await parser.parse(
        'No, cancel the dispatch.',
        _scenarioFixture(),
      );

      expect(selections, hasLength(1));
      expect(selections.single.actionId, const ZaraActionId('dispatch'));
      expect(selections.single.modifier, ZaraActionSelectionModifier.reject);
    });

    test('parses partial approval', () async {
      final parser = ZaraIntentParser(
        ollamaService: _CannedOllamaService(
          responsesByControllerText: <String, String>{
            'Send the client update but stand down dispatch.': _selectionJson(
              <Map<String, String>>[
                <String, String>{'action_id': 'message', 'modifier': 'approve'},
                <String, String>{
                  'action_id': 'dispatch',
                  'modifier': 'approve',
                },
              ],
            ),
          },
        ),
      );

      final selections = await parser.parse(
        'Send the client update but stand down dispatch.',
        _scenarioFixture(),
      );

      expect(selections, hasLength(2));
      expect(
        selections.map((selection) => selection.actionId?.value),
        containsAll(<String>['message', 'dispatch']),
      );
      expect(
        selections.every(
          (selection) =>
              selection.modifier == ZaraActionSelectionModifier.approve,
        ),
        isTrue,
      );
    });

    test('parses modified approval', () async {
      final parser = ZaraIntentParser(
        ollamaService: _CannedOllamaService(
          responsesByControllerText: <String, String>{
            'Send the client message but say we are keeping watch overnight.':
                _selectionJson(<Map<String, String>>[
                  <String, String>{
                    'action_id': 'message',
                    'modifier': 'modify',
                    'draft_edits':
                        'Tell the client we are keeping watch overnight.',
                  },
                ]),
          },
        ),
      );

      final selections = await parser.parse(
        'Send the client message but say we are keeping watch overnight.',
        _scenarioFixture(),
      );

      expect(selections, hasLength(1));
      expect(selections.single.actionId, const ZaraActionId('message'));
      expect(selections.single.modifier, ZaraActionSelectionModifier.modify);
      expect(
        selections.single.draftEdits,
        'Tell the client we are keeping watch overnight.',
      );
    });

    test('returns clarification for unclear input', () async {
      final parser = ZaraIntentParser(
        ollamaService: _CannedOllamaService(
          responsesByControllerText: <String, String>{
            'Maybe later.':
                '{"selections":[],"clarification":"Which action should Zara take?"}',
          },
        ),
      );

      final selections = await parser.parse('Maybe later.', _scenarioFixture());

      expect(selections, hasLength(1));
      expect(selections.single.actionId, isNull);
      expect(selections.single.modifier, ZaraActionSelectionModifier.unclear);
      expect(
        selections.single.clarificationRequest,
        'Which action should Zara take?',
      );
    });

    test('parses multi-action approval from one sentence', () async {
      final parser = ZaraIntentParser(
        ollamaService: _CannedOllamaService(
          responsesByControllerText: <String, String>{
            'Send the client update, stand down dispatch, and keep monitoring.':
                _selectionJson(<Map<String, String>>[
                  <String, String>{
                    'action_id': 'message',
                    'modifier': 'approve',
                  },
                  <String, String>{
                    'action_id': 'dispatch',
                    'modifier': 'approve',
                  },
                  <String, String>{
                    'action_id': 'monitor',
                    'modifier': 'approve',
                  },
                ]),
          },
        ),
      );

      final selections = await parser.parse(
        'Send the client update, stand down dispatch, and keep monitoring.',
        _scenarioFixture(),
      );

      expect(selections, hasLength(3));
      expect(
        selections.map((selection) => selection.actionId?.value),
        containsAll(<String>['message', 'dispatch', 'monitor']),
      );
    });
  });
}

class _CannedOllamaService implements OllamaService {
  final Map<String, String> responsesByControllerText;

  const _CannedOllamaService({required this.responsesByControllerText});

  @override
  bool get isConfigured => true;

  @override
  Future<String?> generate({
    required String systemPrompt,
    required String userPrompt,
    required String model,
  }) async {
    for (final entry in responsesByControllerText.entries) {
      if (userPrompt.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}

ZaraScenario _scenarioFixture() {
  return ZaraScenario(
    id: const ZaraScenarioId('scenario-1'),
    kind: ZaraScenarioKind.alarmTriage,
    createdAt: DateTime.utc(2026, 4, 17, 9, 0),
    originEventIds: const <String>['listener-alarm-advisory-1'],
    summary:
        'Alarm at Ms Vallee Residence. Checked footage and weather. Would you like me to send a client update and stand down dispatch?',
    proposedActions: <ZaraAction>[
      ZaraAction(
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
          draftText: 'Initial draft',
          originalDraftText: 'Initial draft',
        ),
      ),
      ZaraAction(
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
      ZaraAction(
        id: const ZaraActionId('monitor'),
        kind: ZaraActionKind.continueMonitoring,
        label: 'Keep monitoring the property',
        reversible: false,
        confirmRequired: true,
        payload: const ZaraMonitoringPayload(
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          detail: 'Monitoring remains active.',
        ),
      ),
    ],
    relatedSiteId: 'SITE-MS-VALLEE-RESIDENCE',
    relatedDispatchIds: const <String>['ALARM-1'],
    urgency: ZaraScenarioUrgency.attention,
    lifecycleState: ZaraScenarioLifecycleState.awaitingController,
  );
}

String _selectionJson(List<Map<String, String>> selections) {
  final encodedSelections = selections
      .map((selection) {
        final actionId = selection['action_id'] ?? '';
        final modifier = selection['modifier'] ?? 'approve';
        final draftEdits = selection['draft_edits'] ?? '';
        return '{"action_id":"$actionId","modifier":"$modifier","draft_edits":"$draftEdits","clarification":""}';
      })
      .join(',');
  return '{"selections":[$encodedSelections],"clarification":""}';
}
