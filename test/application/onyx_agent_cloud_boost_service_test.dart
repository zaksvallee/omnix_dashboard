import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/onyx_agent_cloud_boost_service.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

void main() {
  test('unconfigured cloud boost returns null', () async {
    const service = UnconfiguredOnyxAgentCloudBoostService();

    final result = await service.boost(
      prompt: 'Summarize the active incident',
      scope: const OnyxAgentCloudScope(),
      intent: OnyxAgentCloudIntent.general,
    );

    expect(result, isNull);
  });

  test(
    'openai cloud boost posts to responses api and parses output text',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://api.openai.com/v1/responses');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['model'], 'gpt-4.1-mini');
        final input = body['input'] as List<Object?>;
        final system = input.first as Map<String, Object?>;
        final content = system['content'] as List<Object?>;
        expect(content, hasLength(2));
        expect(
          (content[1] as Map<String, Object?>)['text'],
          'Operational context: Active dispatches: 1. Awaiting response: 1.',
        );
        return http.Response(
          jsonEncode({
            'output_text':
                'Verify CCTV context first, then keep Track open while the controller confirms the next client-safe update.',
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final service = OpenAiOnyxAgentCloudBoostService(
        client: client,
        apiKey: 'test-key',
        model: 'gpt-4.1-mini',
      );

      final result = await service.boost(
        prompt: 'Correlate alarms, telemetry, and CCTV for the active incident',
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
      expect(result!.providerLabel, 'openai:gpt-4.1-mini');
      expect(result.text, contains('Verify CCTV context first'));
    },
  );

  test('openai cloud boost parses structured JSON advisories', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'output_text': jsonEncode({
            'summary': 'Visual confirmation is still the cleanest next read.',
            'recommended_target': 'cctvReview',
            'confidence': 0.84,
            'why':
                'The live signal still depends on CCTV evidence before escalation.',
            'missing_info': ['fresh clip confirmation', 'guard ETA'],
            'primary_pressure': 'operator focus hold',
            'context_highlights': [
              'Outstanding visual confirmation before escalation',
            ],
            'operator_focus_note':
                'manual context preserved on Client reassurance while urgent review remains visible on Track drift warning.',
            'follow_up_label': 'RECHECK CCTV CONFIRMATION',
            'follow_up_prompt':
                'Recheck CCTV confirmation for the active incident before widening the response.',
            'follow_up_status': 'unresolved',
            'text': 'Verify CCTV context first, then keep Tactical Track warm.',
          }),
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final service = OpenAiOnyxAgentCloudBoostService(
      client: client,
      apiKey: 'test-key',
      model: 'gpt-4.1-mini',
    );

    final result = await service.boost(
      prompt: 'What should I look at next?',
      scope: const OnyxAgentCloudScope(),
      intent: OnyxAgentCloudIntent.general,
    );

    expect(result, isNotNull);
    expect(result!.advisory, isNotNull);
    expect(result.advisory!.recommendedTarget, OnyxToolTarget.cctvReview);
    expect(result.advisory!.confidence, closeTo(0.84, 0.001));
    expect(result.advisory!.missingInfo, contains('guard ETA'));
    expect(result.advisory!.primaryPressure, 'operator focus hold');
    expect(
      result.advisory!.contextHighlights,
      contains('Outstanding visual confirmation before escalation'),
    );
    expect(
      result.advisory!.operatorFocusNote,
      'manual context preserved on Client reassurance while urgent review remains visible on Track drift warning.',
    );
    expect(result.advisory!.followUpLabel, 'RECHECK CCTV CONFIRMATION');
    expect(
      result.advisory!.followUpPrompt,
      contains('Recheck CCTV confirmation'),
    );
    expect(result.advisory!.followUpStatus, 'unresolved');
    expect(
      result.text,
      'Verify CCTV context first, then keep Tactical Track warm.',
    );
  });

  test('brain advisory formats shared body support and closing lines', () {
    const advisory = OnyxAgentBrainAdvisory(
      summary: 'Visual confirmation is still the cleanest next read.',
      recommendedTarget: OnyxToolTarget.cctvReview,
      confidence: 0.84,
      why: 'The live signal still depends on CCTV evidence before escalation.',
      missingInfo: <String>['fresh clip confirmation', 'guard ETA'],
      primaryPressure: 'operator focus hold',
      contextHighlights: <String>[
        'Outstanding visual confirmation before escalation',
      ],
      operatorFocusNote:
          'manual context preserved on Client reassurance while urgent review remains visible on Track drift warning.',
      followUpLabel: 'RECHECK CCTV CONFIRMATION',
      followUpPrompt:
          'Recheck CCTV confirmation for the active incident before widening the response.',
      followUpStatus: 'unresolved',
      narrative: 'Verify CCTV context first, then keep Tactical Track warm.',
    );

    expect(
      advisory.commandBodySupportLines(
        primaryPressureLine: 'Primary pressure: operator focus hold.',
        operatorFocusLine:
            'Operator focus preserved on Client reassurance while urgent review remains visible.',
        recommendedDeskLabel: 'CCTV Review',
        orderedContextHighlights: const <String>[
          'Outstanding visual confirmation before escalation',
        ],
      ),
      <String>[
        'Summary: Visual confirmation is still the cleanest next read.',
        'Primary pressure: operator focus hold.',
        'Operator focus preserved on Client reassurance while urgent review remains visible.',
        'Recommended desk: CCTV Review',
        'Why: The live signal still depends on CCTV evidence before escalation.',
        'Context: Outstanding visual confirmation before escalation',
      ],
    );
    expect(
      advisory.commandBodyClosingLines(confidenceLabel: '84% high confidence'),
      <String>[
        'Confidence: 84% high confidence',
        'Missing info: fresh clip confirmation, guard ETA',
        'Next follow-up: RECHECK CCTV CONFIRMATION (unresolved)',
      ],
    );
    expect(
      advisory.commandBodyFooterLines(
        responseText:
            'Verify CCTV context first, then keep Tactical Track warm.',
        providerLabel: 'openai:gpt-4.1-mini',
      ),
      <String>[
        'Narrative: Verify CCTV context first, then keep Tactical Track warm.',
        'Source: openai:gpt-4.1-mini',
      ],
    );
  });

  test(
    'openai cloud boost promotes planner maintenance priority into context highlights',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final input = body['input'] as List<Object?>;
        final system = input.first as Map<String, Object?>;
        final content = system['content'] as List<Object?>;
        expect(
          (content.first as Map<String, Object?>)['text'],
          contains('primary_pressure'),
        );
        expect(
          (content.first as Map<String, Object?>)['text'],
          contains(
            'If operational context includes a planner maintenance priority, echo that pressure as a short first context_highlights item',
          ),
        );
        return http.Response(
          jsonEncode({
            'output_text': jsonEncode({
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
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final service = OpenAiOnyxAgentCloudBoostService(
        client: client,
        apiKey: 'test-key',
        model: 'gpt-4.1-mini',
      );

      final result = await service.boost(
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
    'openai cloud boost includes pending follow-up scope in system input',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final input = body['input'] as List<Object?>;
        final system = input.first as Map<String, Object?>;
        final content = system['content'] as List<Object?>;
        expect(content, hasLength(3));
        expect(
          (content[1] as Map<String, Object?>)['text'],
          'Outstanding thread follow-up: status=overdue desk=dispatchBoard label=RECHECK RESPONDER ETA age_minutes=26 reopen_cycles=2 still_confirm=current responder ETA, follow-up acknowledgment from dispatch partner',
        );
        expect(
          (content[2] as Map<String, Object?>)['text'],
          'Operational context: Active dispatches: 1. Awaiting response: 1.',
        );
        return http.Response(
          jsonEncode({
            'output_text':
                'Recheck the responder ETA before widening the response.',
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final service = OpenAiOnyxAgentCloudBoostService(
        client: client,
        apiKey: 'test-key',
        model: 'gpt-4.1-mini',
      );

      final result = await service.boost(
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

  test('openai cloud boost includes operator focus scope in system input', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final input = body['input'] as List<Object?>;
      final system = input.first as Map<String, Object?>;
      final content = system['content'] as List<Object?>;
      expect(content, hasLength(3));
      expect(
        (content[1] as Map<String, Object?>)['text'],
        'Operator-preserved thread context: current_thread=Client reassurance state=manual_context_preserved urgent_review_thread=Track drift warning reason=manual context preserved over urgent review',
      );
      expect(
        (content[2] as Map<String, Object?>)['text'],
        'Operational context: Operator focus preserved on Client reassurance while urgent review remains visible on Track drift warning.',
      );
      return http.Response(
        jsonEncode({
          'output_text':
              'Keep the manual client thread active while Track drift stays visible.',
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final service = OpenAiOnyxAgentCloudBoostService(
      client: client,
      apiKey: 'test-key',
      model: 'gpt-4.1-mini',
    );

    final result = await service.boost(
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
    'openai cloud boost returns structured error when provider fails',
    () async {
      final client = MockClient((request) async {
        return http.Response('upstream unavailable', 503);
      });
      final service = OpenAiOnyxAgentCloudBoostService(
        client: client,
        apiKey: 'test-key',
        model: 'gpt-4.1-mini',
      );

      final result = await service.boost(
        prompt: 'Draft the next step',
        scope: const OnyxAgentCloudScope(),
        intent: OnyxAgentCloudIntent.general,
      );

      expect(result, isNotNull);
      expect(result!.isError, isTrue);
      expect(result.errorSummary, 'OpenAI brain request failed');
      expect(result.errorDetail, 'Provider returned HTTP 503.');
      expect(result.text, isEmpty);
    },
  );

  test(
    'openai cloud boost returns structured error when request throws',
    () async {
      final client = MockClient((request) async {
        throw StateError('socket offline');
      });
      final service = OpenAiOnyxAgentCloudBoostService(
        client: client,
        apiKey: 'test-key',
        model: 'gpt-4.1-mini',
      );

      final result = await service.boost(
        prompt: 'Draft the next step',
        scope: const OnyxAgentCloudScope(),
        intent: OnyxAgentCloudIntent.general,
      );

      expect(result, isNotNull);
      expect(result!.isError, isTrue);
      expect(result.errorSummary, 'OpenAI brain request failed');
      expect(result.errorDetail, contains('StateError'));
      expect(result.errorDetail, contains('socket offline'));
      expect(result.text, isEmpty);
    },
  );
}
