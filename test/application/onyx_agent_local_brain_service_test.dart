import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/onyx_agent_cloud_boost_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_local_brain_service.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

void main() {
  test('unconfigured local brain returns null', () async {
    const service = UnconfiguredOnyxAgentLocalBrainService();

    final result = await service.synthesize(
      prompt: 'Summarize the active incident',
      scope: const OnyxAgentCloudScope(),
      intent: OnyxAgentCloudIntent.general,
    );

    expect(result, isNull);
  });

  test(
    'ollama local brain posts to chat api and parses message content',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://127.0.0.1:11434/api/chat');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['model'], 'llama3.2:3b');
        expect(body['stream'], false);
        final messages = body['messages'] as List<Object?>;
        expect(messages, hasLength(3));
        expect(
          (messages[1] as Map<String, Object?>)['content'],
          'Operational context: Active dispatches: 1. Awaiting response: 1.',
        );
        return http.Response(
          jsonEncode({
            'message': {
              'content':
                  'Use CCTV for confirmation first, then keep Track open until posture and signal timing align.',
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final service = OllamaOnyxAgentLocalBrainService(
        client: client,
        model: 'llama3.2:3b',
      );

      final result = await service.synthesize(
        prompt: 'Correlate alarms and telemetry for the active incident',
        scope: const OnyxAgentCloudScope(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          incidentReference: 'INC-42',
          sourceRouteLabel: 'Command',
        ),
        intent: OnyxAgentCloudIntent.correlation,
        contextSummary: 'Active dispatches: 1. Awaiting response: 1.',
      );

      expect(result, isNotNull);
      expect(result!.providerLabel, 'local:ollama:llama3.2:3b');
      expect(result.text, contains('Use CCTV for confirmation first'));
    },
  );

  test('ollama local brain parses structured JSON advisories', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'message': {
            'content': jsonEncode({
              'summary':
                  'Dispatch timing is already clear, so Track should stay open next.',
              'recommended_target': 'tacticalTrack',
              'confidence': 78,
              'why':
                  'Field movement is already active and route continuity matters most now.',
              'missing_info': ['fresh responder timestamp'],
              'primary_pressure': 'overdue follow-up',
              'context_highlights': [
                'Outstanding route continuity check before widening',
              ],
              'operator_focus_note':
                  'manual context preserved on Client reassurance while urgent review remains visible on Track drift warning.',
              'follow_up_label': 'RECHECK ROUTE CONTINUITY',
              'follow_up_prompt':
                  'Recheck route continuity for the active incident before widening the response.',
              'follow_up_status': 'overdue',
              'text': 'Keep Tactical Track open and validate route continuity.',
            }),
          },
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final service = OllamaOnyxAgentLocalBrainService(
      client: client,
      model: 'llama3.2:3b',
    );

    final result = await service.synthesize(
      prompt: 'What should I check next?',
      scope: const OnyxAgentCloudScope(),
      intent: OnyxAgentCloudIntent.general,
    );

    expect(result, isNotNull);
    expect(result!.advisory, isNotNull);
    expect(result.advisory!.recommendedTarget, OnyxToolTarget.tacticalTrack);
    expect(result.advisory!.confidence, closeTo(0.78, 0.001));
    expect(result.advisory!.missingInfo, contains('fresh responder timestamp'));
    expect(result.advisory!.primaryPressure, 'overdue follow-up');
    expect(
      result.advisory!.contextHighlights,
      contains('Outstanding route continuity check before widening'),
    );
    expect(
      result.advisory!.operatorFocusNote,
      'manual context preserved on Client reassurance while urgent review remains visible on Track drift warning.',
    );
    expect(result.advisory!.followUpLabel, 'RECHECK ROUTE CONTINUITY');
    expect(
      result.advisory!.followUpPrompt,
      contains('Recheck route continuity'),
    );
    expect(result.advisory!.followUpStatus, 'overdue');
    expect(
      result.text,
      'Keep Tactical Track open and validate route continuity.',
    );
  });

  test(
    'ollama local brain promotes planner maintenance priority into context highlights',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final messages = body['messages'] as List<Object?>;
        expect(
          (messages.first as Map<String, Object?>)['content'],
          contains('primary_pressure'),
        );
        expect(
          (messages.first as Map<String, Object?>)['content'],
          contains(
            'If operational context includes a planner maintenance priority, echo that pressure as a short first context_highlights item',
          ),
        );
        return http.Response(
          jsonEncode({
            'message': {
              'content': jsonEncode({
                'summary': 'Track drift still needs a manual review.',
                'recommended_target': 'dispatchBoard',
                'confidence': 0.73,
                'why': 'Dispatch still owns the next timing check.',
                'context_highlights': [
                  'Dispatch timing still needs confirmation',
                ],
                'text':
                    'Keep Dispatch Board live while the rule review stays hot.',
              }),
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final service = OllamaOnyxAgentLocalBrainService(
        client: client,
        model: 'llama3.2:3b',
      );

      final result = await service.synthesize(
        prompt: 'What should I keep warm next?',
        scope: const OnyxAgentCloudScope(),
        intent: OnyxAgentCloudIntent.general,
        contextSummary:
            'Planner maintenance priority: Completed maintenance review for chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step has gone stale after the drift worsened again. Reactivated 4 times. Planner review is back in queue. Planner maintenance alert: Completed maintenance review for chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step has gone stale after the drift worsened again.',
      );

      expect(result, isNotNull);
      expect(result!.advisory, isNotNull);
      expect(result.advisory!.primaryPressure, 'planner maintenance');
      expect(
        result.advisory!.contextHighlights.first,
        'Top maintenance pressure: Completed maintenance review for chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step has gone stale after the drift worsened again.',
      );
      expect(
        result.advisory!.contextHighlights,
        contains('Dispatch timing still needs confirmation'),
      );
    },
  );

  test(
    'ollama local brain includes pending follow-up scope in system messages',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final messages = body['messages'] as List<Object?>;
        expect(messages, hasLength(4));
        expect(
          (messages[1] as Map<String, Object?>)['content'],
          'Outstanding thread follow-up: status=overdue desk=dispatchBoard label=RECHECK RESPONDER ETA age_minutes=26 reopen_cycles=2 still_confirm=current responder ETA, follow-up acknowledgment from dispatch partner',
        );
        expect(
          (messages[2] as Map<String, Object?>)['content'],
          'Operational context: Active dispatches: 1. Awaiting response: 1.',
        );
        return http.Response(
          jsonEncode({
            'message': {
              'content': 'Recheck the responder ETA before widening.',
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final service = OllamaOnyxAgentLocalBrainService(
        client: client,
        model: 'llama3.2:3b',
      );

      final result = await service.synthesize(
        prompt: 'What still needs confirmation before we escalate?',
        scope: const OnyxAgentCloudScope(
          pendingFollowUpLabel: 'RECHECK RESPONDER ETA',
          pendingFollowUpPrompt: 'Status? Recheck the delayed response.',
          pendingFollowUpTarget: OnyxToolTarget.dispatchBoard,
          pendingFollowUpStatus: 'overdue',
          pendingFollowUpAgeMinutes: 26,
          pendingFollowUpReopenCycles: 2,
          pendingConfirmations: <String>[
            'current responder ETA',
            'follow-up acknowledgment from dispatch partner',
          ],
        ),
        intent: OnyxAgentCloudIntent.general,
        contextSummary: 'Active dispatches: 1. Awaiting response: 1.',
      );

      expect(result, isNotNull);
      expect(result!.text, contains('Recheck the responder ETA'));
    },
  );

  test('ollama local brain includes operator focus scope in system messages', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final messages = body['messages'] as List<Object?>;
      expect(messages, hasLength(4));
      expect(
        (messages[1] as Map<String, Object?>)['content'],
        'Operator-preserved thread context: current_thread=Client reassurance state=manual_context_preserved urgent_review_thread=Track drift warning reason=manual context preserved over urgent review',
      );
      expect(
        (messages[2] as Map<String, Object?>)['content'],
        'Operational context: Operator focus preserved on Client reassurance while urgent review remains visible on Track drift warning.',
      );
      return http.Response(
        jsonEncode({
          'message': {
            'content':
                'Keep the manual client thread active while Track drift stays visible.',
          },
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final service = OllamaOnyxAgentLocalBrainService(
      client: client,
      model: 'llama3.2:3b',
    );

    final result = await service.synthesize(
      prompt: 'Summarize this manual thread before we switch desks.',
      scope: const OnyxAgentCloudScope(
        operatorFocusPreserved: true,
        operatorFocusThreadTitle: 'Client reassurance',
        operatorFocusUrgentThreadTitle: 'Track drift warning',
      ),
      intent: OnyxAgentCloudIntent.general,
      contextSummary:
          'Operator focus preserved on Client reassurance while urgent review remains visible on Track drift warning.',
    );

    expect(result, isNotNull);
    expect(result!.text, contains('manual client thread'));
  });

  test(
    'ollama local brain returns structured error when provider fails',
    () async {
      final client = MockClient((request) async {
        return http.Response('service unavailable', 503);
      });
      final service = OllamaOnyxAgentLocalBrainService(
        client: client,
        model: 'llama3.2:3b',
      );

      final result = await service.synthesize(
        prompt: 'Draft the next step',
        scope: const OnyxAgentCloudScope(),
        intent: OnyxAgentCloudIntent.general,
      );

      expect(result, isNotNull);
      expect(result!.isError, isTrue);
      expect(result.errorSummary, 'Local brain request failed');
      expect(result.errorDetail, 'Provider returned HTTP 503.');
      expect(result.text, isEmpty);
    },
  );

  test(
    'ollama local brain returns structured error when request throws',
    () async {
      final client = MockClient((request) async {
        throw StateError('ollama offline');
      });
      final service = OllamaOnyxAgentLocalBrainService(
        client: client,
        model: 'llama3.2:3b',
      );

      final result = await service.synthesize(
        prompt: 'Draft the next step',
        scope: const OnyxAgentCloudScope(),
        intent: OnyxAgentCloudIntent.general,
      );

      expect(result, isNotNull);
      expect(result!.isError, isTrue);
      expect(result.errorSummary, 'Local brain request failed');
      expect(result.errorDetail, contains('StateError'));
      expect(result.errorDetail, contains('ollama offline'));
      expect(result.text, isEmpty);
    },
  );
}
