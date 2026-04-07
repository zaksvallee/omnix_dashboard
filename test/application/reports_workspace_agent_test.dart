import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/onyx_claude_report_config.dart';
import 'package:omnix_dashboard/application/reports_workspace_agent.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_audience.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_sections.dart';

import '../fixtures/report_test_bundle.dart';

void main() {
  group('ReportsWorkspaceAgent.generateNarrative', () {
    test('returns a structured narrative on success', () async {
      final agent = ReportsWorkspaceAgent(
        config: const OnyxClaudeReportConfig(apiKey: 'test-key'),
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['max_tokens'], 2048);
          return http.Response(
            _anthropicNarrativeResponse(_validNarrativeJson),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );

      final result = await agent.generateNarrative(
        bundle: buildTestReportBundle(
          guardPerformance: const <GuardPerformanceSnapshot>[
            GuardPerformanceSnapshot(
              guardName: 'Lebo Mokoena',
              idNumber: 'G-001',
              psiraNumber: 'PSIRA-441',
              rank: 'Supervisor',
              compliancePercentage: 97.4,
              escalationsHandled: 1,
            ),
          ],
        ),
        audience: ReportAudience.client,
      );

      expect(result.modelId, 'claude-sonnet-4-6');
      expect(result.executiveHeadline, 'Operations remained stable through March.');
      expect(
        result.supervisorOperationalSummary,
        'Operations remained stable with consistent watch routines across the month.',
      );
      expect(result.companyAchievements, contains('Zero missed client contact windows this month'));
      expect(result.emergingThreats, contains('Short-duration perimeter loitering near the east boundary'));
      expect(result.inputTokens, 412);
      expect(result.outputTokens, 286);
    });

    test('falls back on timeout', () async {
      final agent = ReportsWorkspaceAgent(
        config: const OnyxClaudeReportConfig(
          apiKey: 'test-key',
          timeoutSeconds: 1,
        ),
        httpClient: MockClient((_) {
          return Future<http.Response>.delayed(
            const Duration(seconds: 2),
            () => http.Response(_anthropicNarrativeResponse(_validNarrativeJson), 200),
          );
        }),
      );

      final result = await agent.generateNarrative(
        bundle: buildTestReportBundle(),
        audience: ReportAudience.client,
      );

      _expectFallback(result);
    });

    test('falls back on 4xx responses', () async {
      final agent = ReportsWorkspaceAgent(
        config: const OnyxClaudeReportConfig(apiKey: 'test-key'),
        httpClient: MockClient(
          (_) async => http.Response('{"error":"rate limited"}', 429),
        ),
      );

      final result = await agent.generateNarrative(
        bundle: buildTestReportBundle(),
        audience: ReportAudience.client,
      );

      _expectFallback(result);
    });

    test('falls back on malformed JSON payloads', () async {
      final agent = ReportsWorkspaceAgent(
        config: const OnyxClaudeReportConfig(apiKey: 'test-key'),
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode(<String, Object?>{
              'id': 'msg_test_456',
              'content': <Map<String, Object?>>[
                <String, Object?>{
                  'type': 'text',
                  'text': '{"executiveSummary": ',
                },
              ],
              'usage': const <String, Object?>{
                'input_tokens': 123,
                'output_tokens': 45,
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );

      final result = await agent.generateNarrative(
        bundle: buildTestReportBundle(),
        audience: ReportAudience.client,
      );

      _expectFallback(result);
    });

    test('uses zero-guard and zero-incident prompt wording safely', () async {
      final agent = ReportsWorkspaceAgent(
        config: const OnyxClaudeReportConfig(apiKey: 'test-key'),
        httpClient: MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          final messages = payload['messages'] as List<dynamic>;
          final userPrompt = (messages.first as Map<String, dynamic>)['content']
              .toString();
          expect(userPrompt, contains('Incidents total:         0'));
          expect(userPrompt, contains('Guards on record:        0'));
          expect(
            userPrompt,
            contains('Average compliance:      No guard data available'),
          );
          expect(userPrompt, isNot(contains('Average compliance:      0.0%')));

          return http.Response(
            _anthropicNarrativeResponse(_validNarrativeJson),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );

      final result = await agent.generateNarrative(
        bundle: buildTestReportBundle(),
        audience: ReportAudience.client,
      );

      expect(result.executiveHeadline, 'Operations remained stable through March.');
    });
  });
}

void _expectFallback(dynamic result) {
  expect(result.modelId, 'fallback');
  expect(result.executiveHeadline, isEmpty);
  expect(result.executivePerformanceSummary, isEmpty);
  expect(result.executiveSlaSummary, isEmpty);
  expect(result.executiveRiskSummary, isEmpty);
  expect(result.supervisorOperationalSummary, isEmpty);
  expect(result.supervisorRiskTrend, isEmpty);
  expect(result.supervisorRecommendations, isEmpty);
  expect(result.companyAchievements, isEmpty);
  expect(result.emergingThreats, isEmpty);
  expect(result.inputTokens, 0);
  expect(result.outputTokens, 0);
}

const Map<String, Object?> _validNarrativeJson = <String, Object?>{
  'executiveSummary': <String, Object?>{
    'headline': 'Operations remained stable through March.',
    'performanceSummary':
        'Incident volume remained low while escalation handling stayed controlled.',
    'slaSummary':
        'SLA compliance stayed intact with no recorded breach in this reporting window.',
    'riskSummary':
        'Risk posture stayed contained with one monitored boundary concern.',
  },
  'supervisorAssessment': <String, Object?>{
    'operationalSummary':
        'Operations remained stable with consistent watch routines across the month.',
    'riskTrend':
        'Risk remained stable with low-volume movement patterns and limited escalation pressure.',
    'recommendations':
        'Maintain patrol cadence; keep the east boundary review pattern under active observation',
  },
  'companyAchievements': <String>[
    'Zero missed client contact windows this month',
    'Camera review coverage remained consistent across the reporting cycle',
  ],
  'emergingThreats': <String>[
    'Short-duration perimeter loitering near the east boundary',
    'Repeat low-significance driveway motion after midnight',
  ],
};

String _anthropicNarrativeResponse(Map<String, Object?> narrativeJson) {
  return jsonEncode(<String, Object?>{
    'id': 'msg_test_123',
    'content': <Map<String, Object?>>[
      <String, Object?>{
        'type': 'text',
        'text': jsonEncode(narrativeJson),
      },
    ],
    'usage': const <String, Object?>{
      'input_tokens': 412,
      'output_tokens': 286,
    },
  });
}
