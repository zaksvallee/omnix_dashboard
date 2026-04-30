import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/crm/reporting/client_narrative_result.dart';
import '../domain/crm/reporting/report_audience.dart';
import '../domain/crm/reporting/report_bundle.dart';
import 'onyx_claude_report_config.dart';
import 'zara/anthropic_llm_provider.dart';
import 'zara/llm_provider.dart';

class ReportsWorkspaceAgent {
  final OnyxClaudeReportConfig config;
  final http.Client? httpClient;

  const ReportsWorkspaceAgent({required this.config, this.httpClient});

  Future<ClientNarrativeResult> generateNarrative({
    required ReportBundle bundle,
    required ReportAudience audience,
  }) async {
    final fallback = ClientNarrativeResult.fallback(
      clientId: bundle.clientSnapshot.clientId,
      month: bundle.clientSnapshot.reportingPeriod,
      audience: audience,
    );
    if (!config.isConfigured) {
      return fallback;
    }

    final client = httpClient ?? http.Client();
    final provider = AnthropicLlmProvider(
      client: client,
      config: AnthropicLlmProviderConfig(
        apiKey: config.apiKey,
        primaryModel: config.model,
        escalatedModel: config.model,
        defaultMaxOutputTokens: config.maxTokens,
        requestTimeout: Duration(seconds: config.timeoutSeconds),
      ),
    );
    final generatedAt = DateTime.now().toUtc();
    try {
      final response = await provider.complete(
        messages: <LlmMessage>[
          LlmMessage(role: LlmMessageRole.user, text: _buildUserPrompt(bundle)),
        ],
        systemPrompt: _buildSystemPrompt(audience),
        maxOutputTokens: config.maxTokens,
      );
      if (response.usedFallback || !response.hasText) {
        return fallback;
      }

      final narrativeJson = stringKeyedMap(jsonDecode(response.text));
      if (narrativeJson == null) {
        return fallback;
      }

      return ClientNarrativeResult.fromClaudeJson(
            narrativeJson,
            clientId: bundle.clientSnapshot.clientId,
            month: bundle.clientSnapshot.reportingPeriod,
            audience: audience,
            modelId: response.modelId,
            generatedAt: generatedAt,
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens,
          ) ??
          fallback;
    } catch (_) {
      return fallback;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  String _buildSystemPrompt(ReportAudience audience) {
    final toneInstruction = audience == ReportAudience.client
        ? 'You are writing for the client. Tone: professional, reassuring, factual. '
              'Avoid internal operational jargon. Emphasise value delivered and risk managed.'
        : 'You are writing for internal supervisors. Tone: direct, analytical, candid. '
              'Include risk concerns and operational gaps without softening.';

    return '''
You are the ONYX Intelligence Reporting Agent.
You generate structured narrative sections for monthly security operations reports.
$toneInstruction
Rules:
- No speculation. Every claim must follow from the metrics provided.
- No filler phrases ("it is worth noting", "in conclusion", etc.).
- Maximum output length: ${config.maxTokens} tokens.
- Your ENTIRE response must be a single valid JSON object — no markdown code fences,
  no prose before or after the JSON.

Output JSON schema (all fields required):
{
  "executiveSummary": {
    "headline": "<one sentence, max 20 words, present-tense>",
    "performanceSummary": "<2–3 sentences covering incident volume, escalation rate, guard performance>",
    "slaSummary": "<1–2 sentences on SLA compliance rate and breach context>",
    "riskSummary": "<1–2 sentences on current risk posture based on scene review and escalations>"
  },
  "supervisorAssessment": {
    "operationalSummary": "<2–3 sentences on overall operational stability this period>",
    "riskTrend": "<1–2 sentences on whether risk is increasing, stable, or decreasing and why>",
    "recommendations": "<1–3 concrete operational recommendations as a single string, separated by semicolons>"
  },
  "companyAchievements": ["<achievement 1>", "<achievement 2>"],
  "emergingThreats": ["<observed threat pattern 1>", "<observed threat pattern 2>"]
}
''';
  }

  String _buildUserPrompt(ReportBundle bundle) {
    final sceneReview = bundle.sceneReview;
    final patrolPerformance = bundle.patrolPerformance;
    final monthlyReport = bundle.monthlyReport;
    final clientSnapshot = bundle.clientSnapshot;

    final incidentLines = bundle.incidentDetails
        .take(5)
        .map(
          (incident) =>
              '  - [${incident.riskCategory}] ${incident.incidentId}'
              ' | SLA: ${incident.slaResult}'
              '${incident.overrideApplied ? ' (override applied)' : ''}',
        )
        .join('\n');

    final guardCount = bundle.guardPerformance.length;
    final averageGuardCompliance = guardCount > 0
        ? bundle.guardPerformance
                  .map((guard) => guard.compliancePercentage)
                  .reduce((left, right) => left + right) /
              guardCount
        : 0.0;
    final guardComplianceLine = guardCount > 0
        ? '${averageGuardCompliance.toStringAsFixed(1)}%'
        : 'No guard data available';

    return '''
CLIENT: ${clientSnapshot.clientName} | SITE: ${clientSnapshot.siteName}
PERIOD: ${clientSnapshot.reportingPeriod} | SLA TIER: ${clientSnapshot.slaTier}

PERFORMANCE METRICS:
  Incidents total:         ${monthlyReport.totalIncidents}
  Escalations:             ${monthlyReport.totalEscalations}
  SLA compliance rate:     ${(monthlyReport.slaComplianceRate * 100).toStringAsFixed(1)}%
  SLA breaches:            ${monthlyReport.totalSlaBreaches}
  SLA overrides applied:   ${monthlyReport.totalSlaOverrides}
  Client contacts:         ${monthlyReport.totalClientContacts}

PATROL PERFORMANCE:
  Scheduled:               ${patrolPerformance.scheduledPatrols}
  Completed:               ${patrolPerformance.completedPatrols}
  Missed:                  ${patrolPerformance.missedPatrols}
  Completion rate:         ${(patrolPerformance.completionRate * 100).toStringAsFixed(1)}%

GUARD ROSTER:
  Guards on record:        $guardCount
  Average compliance:      $guardComplianceLine

SCENE REVIEW (AI-assisted):
  Total reviews:           ${sceneReview.totalReviews}
  Model-reviewed:          ${sceneReview.modelReviews}
  Suppressed actions:      ${sceneReview.suppressedActions}
  Escalation candidates:   ${sceneReview.escalationCandidates}
  Incident alerts:         ${sceneReview.incidentAlerts}
  Dominant posture:        ${sceneReview.topPosture}

INCIDENT LOG (latest ${bundle.incidentDetails.take(5).length}):
$incidentLines

Generate the four narrative sections as JSON only.
''';
  }
}
