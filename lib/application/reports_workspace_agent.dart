import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../domain/crm/reporting/client_narrative_result.dart';
import '../domain/crm/reporting/report_audience.dart';
import '../domain/crm/reporting/report_bundle.dart';
import 'onyx_claude_report_config.dart';

class ReportsWorkspaceAgent {
  static const String _endpoint = 'https://api.anthropic.com/v1/messages';
  static const String _anthropicVersion = '2023-06-01';

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
    final generatedAt = DateTime.now().toUtc();
    try {
      final response = await client
          .post(
            Uri.parse(_endpoint),
            headers: <String, String>{
              'content-type': 'application/json',
              'x-api-key': config.apiKey,
              'anthropic-version': _anthropicVersion,
            },
            body: jsonEncode(<String, Object?>{
              'model': config.model,
              'max_tokens': config.maxTokens,
              'system': _buildSystemPrompt(audience),
              'messages': <Map<String, Object?>>[
                <String, Object?>{
                  'role': 'user',
                  'content': _buildUserPrompt(bundle),
                },
              ],
            }),
          )
          .timeout(Duration(seconds: config.timeoutSeconds));
      if (response.statusCode != 200) {
        developer.log(
          'ReportsWorkspaceAgent fallback: Anthropic returned HTTP ${response.statusCode}.',
          name: 'ReportsWorkspaceAgent',
          error: response.body,
        );
        return fallback;
      }

      final responseBody = stringKeyedMap(jsonDecode(response.body));
      if (responseBody == null) {
        developer.log(
          'ReportsWorkspaceAgent fallback: response body was not a string-keyed JSON object.',
          name: 'ReportsWorkspaceAgent',
        );
        return fallback;
      }

      final usage = stringKeyedMap(responseBody['usage']);
      final narrativeText = _extractTextBlock(responseBody['content']);
      if (narrativeText.isEmpty) {
        developer.log(
          'ReportsWorkspaceAgent fallback: Anthropic response did not include a text content block.',
          name: 'ReportsWorkspaceAgent',
        );
        return fallback;
      }

      final narrativeJson = stringKeyedMap(jsonDecode(narrativeText));
      if (narrativeJson == null) {
        developer.log(
          'ReportsWorkspaceAgent fallback: narrative payload was not a string-keyed JSON object.',
          name: 'ReportsWorkspaceAgent',
        );
        return fallback;
      }

      return ClientNarrativeResult.fromClaudeJson(
            narrativeJson,
            clientId: bundle.clientSnapshot.clientId,
            month: bundle.clientSnapshot.reportingPeriod,
            audience: audience,
            modelId: config.model,
            generatedAt: generatedAt,
            inputTokens: _intFromValue(usage?['input_tokens']),
            outputTokens: _intFromValue(usage?['output_tokens']),
          ) ??
          fallback;
    } catch (e, st) {
      developer.log(
        'ReportsWorkspaceAgent fallback: request or parsing failed.',
        name: 'ReportsWorkspaceAgent',
        error: e,
        stackTrace: st,
      );
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

  String _extractTextBlock(Object? contentValue) {
    if (contentValue is! List) {
      return '';
    }
    for (final block in contentValue) {
      final map = stringKeyedMap(block);
      if (map == null) {
        continue;
      }
      if ((map['type'] ?? '').toString() == 'text') {
        return (map['text'] ?? '').toString();
      }
    }
    return '';
  }

  int _intFromValue(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
