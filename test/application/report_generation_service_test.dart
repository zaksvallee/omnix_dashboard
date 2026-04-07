import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/onyx_claude_report_config.dart';
import 'package:omnix_dashboard/application/report_generation_service.dart';
import 'package:omnix_dashboard/application/reports_workspace_agent.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_audience.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_branding_configuration.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_section_configuration.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';

import '../fixtures/report_test_bundle.dart';
import '../fixtures/report_test_intelligence.dart';
import '../fixtures/report_test_receipt.dart';

DateTime _reportGenerationNowUtc() => DateTime.utc(2026, 3, 15, 6, 0);

DateTime _reportReceiptOccurredAtUtc() => DateTime.utc(2026, 3, 14, 22, 0);

DateTime _reportSceneReviewOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 14, hour, minute);

DateTime _reportSceneReviewReviewedAtUtc(
  int hour,
  int minute, [
  int second = 0,
]) => DateTime.utc(2026, 3, 14, hour, minute, second);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportGenerationService scene review receipt summary', () {
    test('generatePdfReport persists report section configuration', () async {
      final service = ReportGenerationService(store: InMemoryEventStore());

      final generated = await service.generatePdfReport(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        nowUtc: _reportGenerationNowUtc(),
        brandingConfiguration: const ReportBrandingConfiguration(
          primaryLabel: 'VISION Tactical',
          endorsementLine: 'Powered by ONYX',
        ),
        sectionConfiguration: const ReportSectionConfiguration(
          includeTimeline: true,
          includeDispatchSummary: false,
          includeCheckpointCompliance: true,
          includeAiDecisionLog: false,
          includeGuardMetrics: true,
        ),
        investigationContextKey: 'governance_branding_drift',
      );

      expect(generated.receiptEvent.reportSchemaVersion, 3);
      expect(generated.receiptEvent.primaryBrandLabel, 'VISION Tactical');
      expect(generated.receiptEvent.endorsementLine, 'Powered by ONYX');
      expect(
        generated.receiptEvent.investigationContextKey,
        'governance_branding_drift',
      );
      expect(generated.receiptEvent.includeTimeline, isTrue);
      expect(generated.receiptEvent.includeDispatchSummary, isFalse);
      expect(generated.receiptEvent.includeCheckpointCompliance, isTrue);
      expect(generated.receiptEvent.includeAiDecisionLog, isFalse);
      expect(generated.receiptEvent.includeGuardMetrics, isTrue);
      expect(generated.bundle.sectionConfiguration.includeTimeline, isTrue);
      expect(
        generated.bundle.sectionConfiguration.includeDispatchSummary,
        isFalse,
      );
      expect(
        generated.bundle.sectionConfiguration.includeCheckpointCompliance,
        isTrue,
      );
      expect(
        generated.bundle.sectionConfiguration.includeAiDecisionLog,
        isFalse,
      );
      expect(generated.bundle.sectionConfiguration.includeGuardMetrics, isTrue);
      expect(
        generated.bundle.brandingConfiguration.primaryLabel,
        'VISION Tactical',
      );
      expect(
        generated.bundle.brandingConfiguration.endorsementLine,
        'Powered by ONYX',
      );
    });

    test('returns embedded scene review metrics for schema v2 receipts', () {
      final store = InMemoryEventStore();
      store.append(
        buildTestIntelligenceReceived(
          eventId: 'evt-1',
          occurredAt: _reportSceneReviewOccurredAtUtc(21, 18),
          intelligenceId: 'intel-1',
          cameraId: 'channel-1',
          headline: 'Repeat movement',
          summary: 'Repeat movement detected.',
          riskScore: 68,
        ),
      );

      final service = ReportGenerationService(
        store: store,
        sceneReviewByIntelligenceId: {
          'intel-1': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-1',
            evidenceRecordHash: 'evidence-1',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'escalation candidate',
            decisionLabel: 'Escalation Candidate',
            summary: reportTestEscalationSummary,
            reviewedAtUtc: _reportSceneReviewReviewedAtUtc(21, 18, 6),
          ),
        },
      );

      final summary = service.summarizeSceneReviewForReceipt(
        buildTestReportGenerated(
          eventId: 'RPT-1',
          occurredAt: _reportReceiptOccurredAtUtc(),
          reportSchemaVersion: 2,
        ),
      );

      expect(summary.includedInReceipt, isTrue);
      expect(summary.totalReviews, 1);
      expect(summary.modelReviews, 1);
      expect(summary.suppressedActions, 0);
      expect(summary.incidentAlerts, 0);
      expect(summary.repeatUpdates, 0);
      expect(summary.escalationCandidates, 1);
      expect(summary.topPosture, 'escalation candidate');
      expect(
        summary.latestActionBucket,
        ReportReceiptLatestActionBucket.escalation,
      );
      expect(
        summary.latestActionTaken,
        '2026-03-14T21:18:00.000Z • Camera 1 • Escalation Candidate • Person visible near the boundary after repeat activity.',
      );
      expect(summary.latestSuppressedPattern, isEmpty);
    });

    test('returns pending summary for pre-scene-review receipts', () {
      final service = ReportGenerationService(store: InMemoryEventStore());

      final summary = service.summarizeSceneReviewForReceipt(
        buildTestReportGenerated(
          eventId: 'RPT-LEGACY',
          occurredAt: _reportReceiptOccurredAtUtc(),
          eventRangeStart: 0,
          eventRangeEnd: 0,
          eventCount: 0,
          reportSchemaVersion: 1,
        ),
      );

      expect(summary.includedInReceipt, isFalse);
      expect(summary.totalReviews, 0);
      expect(summary.suppressedActions, 0);
      expect(summary.topPosture, 'none');
      expect(summary.latestActionBucket, ReportReceiptLatestActionBucket.none);
      expect(summary.latestActionTaken, isEmpty);
      expect(summary.latestSuppressedPattern, isEmpty);
    });

    test('returns latest suppressed pattern for reviewed receipts', () {
      final store = InMemoryEventStore();
      store.append(
        buildTestIntelligenceReceived(
          eventId: 'evt-2',
          occurredAt: _reportSceneReviewOccurredAtUtc(21, 16),
          intelligenceId: 'intel-2',
          cameraId: 'channel-3',
          headline: 'Low significance motion',
          summary: 'Low significance motion detected.',
          riskScore: 21,
        ),
      );

      final service = ReportGenerationService(
        store: store,
        sceneReviewByIntelligenceId: {
          'intel-2': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-2',
            evidenceRecordHash: 'evidence-2',
            sourceLabel: 'metadata:fallback',
            postureLabel: 'reviewed',
            decisionLabel: 'Suppressed Review',
            decisionSummary: reportTestSuppressedDecisionSummary,
            summary: 'Routine vehicle motion remained internal.',
            reviewedAtUtc: _reportSceneReviewReviewedAtUtc(21, 16, 5),
          ),
        },
      );

      final summary = service.summarizeSceneReviewForReceipt(
        buildTestReportGenerated(
          eventId: 'RPT-2',
          occurredAt: _reportReceiptOccurredAtUtc(),
          reportSchemaVersion: 2,
        ),
      );

      expect(summary.suppressedActions, 1);
      expect(
        summary.latestActionBucket,
        ReportReceiptLatestActionBucket.suppressed,
      );
      expect(summary.latestActionTaken, isEmpty);
      expect(
        summary.latestSuppressedPattern,
        reportTestLatestSuppressedPattern,
      );
    });

    test('returns not included summary when ai decision log is disabled', () {
      final service = ReportGenerationService(store: InMemoryEventStore());

      final summary = service.summarizeSceneReviewForReceipt(
        buildTestReportGenerated(
          eventId: 'RPT-NO-AI-LOG',
          occurredAt: _reportReceiptOccurredAtUtc(),
          reportSchemaVersion: 3,
          includeAiDecisionLog: false,
        ),
      );

      expect(summary.includedInReceipt, isFalse);
      expect(summary.totalReviews, 0);
      expect(summary.topPosture, 'not included');
      expect(summary.latestActionBucket, ReportReceiptLatestActionBucket.none);
    });
  });

  group('ReportGenerationService narrative agent integration', () {
    test(
      'generatePdfReport injects a successful Claude narrative without changing the canonical receipt hash',
      () async {
        final baselineService = ReportGenerationService(
          store: InMemoryEventStore(),
        );
        final baseline = await baselineService.generatePdfReport(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          nowUtc: _reportGenerationNowUtc(),
        );

        final service = ReportGenerationService(store: InMemoryEventStore());
        final agent = ReportsWorkspaceAgent(
          config: const OnyxClaudeReportConfig(apiKey: 'test-key'),
          httpClient: MockClient((request) async {
            expect(
              request.url.toString(),
              'https://api.anthropic.com/v1/messages',
            );
            expect(request.headers['x-api-key'], 'test-key');
            expect(request.headers['anthropic-version'], '2023-06-01');
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            expect(payload['model'], 'claude-sonnet-4-6');
            expect(payload['max_tokens'], 2048);
            expect(
              (payload['system'] ?? '').toString(),
              contains('JSON object'),
            );
            expect(
              ((payload['messages'] as List).first as Map)['role'],
              'user',
            );
            return http.Response(
              _anthropicNarrativeResponse(_validNarrativeJson),
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }),
        );

        final generated = await service.generatePdfReport(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          nowUtc: _reportGenerationNowUtc(),
          narrativeAgent: agent,
          audience: ReportAudience.client,
        );

        expect(
          generated.bundle.executiveSummary.headline,
          'Operations remained stable through March.',
        );
        expect(
          generated.bundle.executiveSummary.performanceSummary,
          'Incident volume remained low while escalation handling stayed controlled.',
        );
        expect(
          generated.bundle.supervisorAssessment.operationalSummary,
          'Operations remained stable with consistent watch routines across the month.',
        );
        expect(
          generated.bundle.companyAchievements.highlights,
          contains('Zero missed client contact windows this month'),
        );
        expect(
          generated.bundle.emergingThreats.patternsObserved,
          contains('Short-duration perimeter loitering near the east boundary'),
        );
        expect(
          generated.receiptEvent.contentHash,
          baseline.receiptEvent.contentHash,
        );
        expect(await service.verifyReportHash(generated.receiptEvent), isTrue);
      },
    );

    test(
      'generatePdfReport falls back to the template when the API fails',
      () async {
        final baselineService = ReportGenerationService(
          store: InMemoryEventStore(),
        );
        final baseline = await baselineService.generatePdfReport(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          nowUtc: _reportGenerationNowUtc(),
        );

        final service = ReportGenerationService(store: InMemoryEventStore());
        final agent = ReportsWorkspaceAgent(
          config: const OnyxClaudeReportConfig(apiKey: 'test-key'),
          httpClient: MockClient(
            (_) async => http.Response('{"error":"upstream failed"}', 500),
          ),
        );

        final generated = await service.generatePdfReport(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          nowUtc: _reportGenerationNowUtc(),
          narrativeAgent: agent,
        );

        expect(
          generated.bundle.executiveSummary.headline,
          baseline.bundle.executiveSummary.headline,
        );
        expect(
          generated.bundle.supervisorAssessment.operationalSummary,
          baseline.bundle.supervisorAssessment.operationalSummary,
        );
        expect(
          generated.bundle.companyAchievements.highlights,
          baseline.bundle.companyAchievements.highlights,
        );
        expect(
          generated.bundle.emergingThreats.patternsObserved,
          baseline.bundle.emergingThreats.patternsObserved,
        );
      },
    );

    test(
      'generatePdfReport gracefully keeps the template when Claude returns partial JSON',
      () async {
        final baselineService = ReportGenerationService(
          store: InMemoryEventStore(),
        );
        final baseline = await baselineService.generatePdfReport(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          nowUtc: _reportGenerationNowUtc(),
        );

        final service = ReportGenerationService(store: InMemoryEventStore());
        final agent = ReportsWorkspaceAgent(
          config: const OnyxClaudeReportConfig(apiKey: 'test-key'),
          httpClient: MockClient((_) async {
            return http.Response(
              _anthropicNarrativeResponse(<String, Object?>{
                'executiveSummary': <String, Object?>{
                  'headline': 'Partial output should not break generation.',
                },
                'supervisorAssessment': <String, Object?>{
                  'operationalSummary': 'Incomplete output',
                },
                'companyAchievements': <String>['One highlight'],
              }),
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }),
        );

        final generated = await service.generatePdfReport(
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          nowUtc: _reportGenerationNowUtc(),
          narrativeAgent: agent,
        );

        expect(
          generated.bundle.executiveSummary.headline,
          baseline.bundle.executiveSummary.headline,
        );
        expect(
          generated.bundle.supervisorAssessment.operationalSummary,
          baseline.bundle.supervisorAssessment.operationalSummary,
        );
        expect(
          generated.bundle.companyAchievements.highlights,
          baseline.bundle.companyAchievements.highlights,
        );
        expect(
          generated.bundle.emergingThreats.patternsObserved,
          baseline.bundle.emergingThreats.patternsObserved,
        );
      },
    );
  });
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
      <String, Object?>{'type': 'text', 'text': jsonEncode(narrativeJson)},
    ],
    'usage': const <String, Object?>{'input_tokens': 321, 'output_tokens': 123},
  });
}
