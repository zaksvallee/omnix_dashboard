# Spec: Reports Workspace Agent — Phase 1: Claude API Integration Layer

- Date: 2026-04-07
- Author: Claude Code
- Scope: Domain contract + Agent service + ReportGenerationService integration point
- Status: Implementation spec for Codex
- Read-only: yes (this document is a specification only — no code changes made)

---

## Overview

Phase 1 delivers the minimum slice that allows `ReportGenerationService` to produce AI-narrated PDFs using Claude. It covers four deliverables:

1. `OnyxClaudeReportConfig` — config value object (reads API key + model params from env/json)
2. `ClientNarrativeResult` — domain type that carries parsed Claude output
3. `ReportBundle.withNarrative()` — pure copy method that injects a `ClientNarrativeResult` into a bundle
4. `ReportsWorkspaceAgent` — application service that calls `api.anthropic.com/v1/messages` and returns a `ClientNarrativeResult?`

The agent slots into `ReportGenerationService.generatePdfReport()` as an optional, backwards-compatible step. The canonical hash is computed from the template bundle (before narrative injection), preserving replay integrity.

---

## 1. Exact File Structure

### New files (Codex creates)

```
lib/
  application/
    onyx_claude_report_config.dart       ← config value object
    reports_workspace_agent.dart         ← HTTP caller + prompt builder + response parser
  domain/
    crm/
      reporting/
        client_narrative_result.dart     ← domain type carrying parsed Claude output
```

### Modified files (Codex edits)

```
lib/
  domain/
    crm/
      reporting/
        report_bundle.dart               ← add withNarrative(ClientNarrativeResult) method
  application/
    report_generation_service.dart       ← add optional narrativeAgent + audience params
config/
  onyx.local.example.json                ← add "ONYX_CLAUDE_API_KEY", "ONYX_CLAUDE_MODEL",
                                            "ONYX_CLAUDE_MAX_TOKENS", "ONYX_CLAUDE_TIMEOUT_SECONDS"
```

No other files are touched in Phase 1. `ExecutiveSummaryGenerator`, `ReportBundleAssembler`,
`ReportBundleCanonicalizer`, and `PDFReportExporter` are unchanged.

---

## 2. Class Names and Method Signatures

### 2.1 `OnyxClaudeReportConfig`

**File:** `lib/application/onyx_claude_report_config.dart`

```dart
class OnyxClaudeReportConfig {
  final String apiKey;
  final String model;
  final int maxTokens;
  final int timeoutSeconds;

  const OnyxClaudeReportConfig({
    required this.apiKey,
    this.model = 'claude-sonnet-4-6',
    this.maxTokens = 1024,
    this.timeoutSeconds = 30,
  });

  /// Reads from a flat string map (environment or parsed JSON config).
  /// Keys: ONYX_CLAUDE_API_KEY, ONYX_CLAUDE_MODEL, ONYX_CLAUDE_MAX_TOKENS,
  ///       ONYX_CLAUDE_TIMEOUT_SECONDS
  factory OnyxClaudeReportConfig.fromEnv(Map<String, String> env) {
    return OnyxClaudeReportConfig(
      apiKey: env['ONYX_CLAUDE_API_KEY'] ?? '',
      model: env['ONYX_CLAUDE_MODEL'] ?? 'claude-sonnet-4-6',
      maxTokens: int.tryParse(env['ONYX_CLAUDE_MAX_TOKENS'] ?? '') ?? 1024,
      timeoutSeconds:
          int.tryParse(env['ONYX_CLAUDE_TIMEOUT_SECONDS'] ?? '') ?? 30,
    );
  }

  /// True only when an API key is present. Used by ReportsWorkspaceAgent
  /// to fast-return null without making a network call.
  bool get isConfigured => apiKey.isNotEmpty;
}
```

**Config keys to add to `config/onyx.local.example.json`:**

```json
"ONYX_CLAUDE_API_KEY": "sk-ant-your-key-here",
"ONYX_CLAUDE_MODEL": "claude-sonnet-4-6",
"ONYX_CLAUDE_MAX_TOKENS": "1024",
"ONYX_CLAUDE_TIMEOUT_SECONDS": "30"
```

---

### 2.2 `ClientNarrativeResult`

**File:** `lib/domain/crm/reporting/client_narrative_result.dart`

```dart
import 'report_audience.dart';

class ClientNarrativeResult {
  final String clientId;
  final String month;                        // YYYY-MM
  final ReportAudience audience;

  // ExecutiveSummary injection targets
  final String executiveHeadline;            // → ExecutiveSummary.headline
  final String executivePerformanceSummary;  // → ExecutiveSummary.performanceSummary
  final String executiveSlaSummary;          // → ExecutiveSummary.slaSummary
  final String executiveRiskSummary;         // → ExecutiveSummary.riskSummary

  // SupervisorAssessment injection targets
  final String supervisorOperationalSummary; // → SupervisorAssessment.operationalSummary
  final String supervisorRiskTrend;          // → SupervisorAssessment.riskTrend
  final String supervisorRecommendations;    // → SupervisorAssessment.recommendations

  // List section injection targets
  final List<String> companyAchievements;    // → CompanyAchievementsSnapshot.highlights
  final List<String> emergingThreats;        // → EmergingThreatSnapshot.patternsObserved

  // Audit / traceability fields
  final String modelId;                      // e.g. "claude-sonnet-4-6"
  final DateTime generatedAt;
  final int inputTokens;
  final int outputTokens;

  const ClientNarrativeResult({
    required this.clientId,
    required this.month,
    required this.audience,
    required this.executiveHeadline,
    required this.executivePerformanceSummary,
    required this.executiveSlaSummary,
    required this.executiveRiskSummary,
    required this.supervisorOperationalSummary,
    required this.supervisorRiskTrend,
    required this.supervisorRecommendations,
    required this.companyAchievements,
    required this.emergingThreats,
    required this.modelId,
    required this.generatedAt,
    required this.inputTokens,
    required this.outputTokens,
  });

  /// Returns a result populated with empty strings and empty lists.
  /// Used as a safe fallback when the API is unavailable or unconfigured.
  /// Mirrors what ReportBundleAssembler currently produces (SupervisorAssessment.empty(),
  /// CompanyAchievementsSnapshot.empty(), EmergingThreatSnapshot.empty()).
  factory ClientNarrativeResult.fallback({
    required String clientId,
    required String month,
    required ReportAudience audience,
  }) {
    return ClientNarrativeResult(
      clientId: clientId,
      month: month,
      audience: audience,
      executiveHeadline: '',
      executivePerformanceSummary: '',
      executiveSlaSummary: '',
      executiveRiskSummary: '',
      supervisorOperationalSummary: '',
      supervisorRiskTrend: '',
      supervisorRecommendations: '',
      companyAchievements: const [],
      emergingThreats: const [],
      modelId: 'fallback',
      generatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      inputTokens: 0,
      outputTokens: 0,
    );
  }

  /// Parses the structured JSON object returned by Claude.
  /// Returns null if any required top-level key is absent or malformed.
  /// Callers treat null as "use template fallback."
  static ClientNarrativeResult? fromClaudeJson(
    Map<String, dynamic> json, {
    required String clientId,
    required String month,
    required ReportAudience audience,
    required String modelId,
    required DateTime generatedAt,
    required int inputTokens,
    required int outputTokens,
  }) {
    final exec = json['executiveSummary'];
    final supervisor = json['supervisorAssessment'];
    final achievements = json['companyAchievements'];
    final threats = json['emergingThreats'];

    if (exec is! Map<String, dynamic> ||
        supervisor is! Map<String, dynamic> ||
        achievements is! List ||
        threats is! List) {
      return null;
    }

    return ClientNarrativeResult(
      clientId: clientId,
      month: month,
      audience: audience,
      executiveHeadline: exec['headline']?.toString() ?? '',
      executivePerformanceSummary: exec['performanceSummary']?.toString() ?? '',
      executiveSlaSummary: exec['slaSummary']?.toString() ?? '',
      executiveRiskSummary: exec['riskSummary']?.toString() ?? '',
      supervisorOperationalSummary:
          supervisor['operationalSummary']?.toString() ?? '',
      supervisorRiskTrend: supervisor['riskTrend']?.toString() ?? '',
      supervisorRecommendations: supervisor['recommendations']?.toString() ?? '',
      companyAchievements:
          achievements.whereType<String>().toList(growable: false),
      emergingThreats:
          threats.whereType<String>().toList(growable: false),
      modelId: modelId,
      generatedAt: generatedAt,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );
  }
}
```

---

### 2.3 `ReportBundle.withNarrative()`

**File:** `lib/domain/crm/reporting/report_bundle.dart` — add this method to `ReportBundle`

```dart
/// Returns a new ReportBundle with ExecutiveSummary, SupervisorAssessment,
/// CompanyAchievementsSnapshot, and EmergingThreatSnapshot replaced by
/// AI-generated content from [narrative].
///
/// All other fields are carried over unchanged.
/// Non-empty prose fields in [narrative] replace the corresponding template
/// fields. Empty strings fall through to whatever was already set.
ReportBundle withNarrative(ClientNarrativeResult narrative) {
  return ReportBundle(
    monthlyReport: monthlyReport,
    executiveSummary: ExecutiveSummary(
      clientId: executiveSummary.clientId,
      month: executiveSummary.month,
      headline: narrative.executiveHeadline.isNotEmpty
          ? narrative.executiveHeadline
          : executiveSummary.headline,
      performanceSummary: narrative.executivePerformanceSummary.isNotEmpty
          ? narrative.executivePerformanceSummary
          : executiveSummary.performanceSummary,
      slaSummary: narrative.executiveSlaSummary.isNotEmpty
          ? narrative.executiveSlaSummary
          : executiveSummary.slaSummary,
      riskSummary: narrative.executiveRiskSummary.isNotEmpty
          ? narrative.executiveRiskSummary
          : executiveSummary.riskSummary,
    ),
    siteComparisons: siteComparisons,
    escalationTrend: escalationTrend,
    clientSnapshot: clientSnapshot,
    guardPerformance: guardPerformance,
    patrolPerformance: patrolPerformance,
    incidentDetails: incidentDetails,
    sceneReview: sceneReview,
    brandingConfiguration: brandingConfiguration,
    sectionConfiguration: sectionConfiguration,
    supervisorAssessment: SupervisorAssessment(
      operationalSummary: narrative.supervisorOperationalSummary.isNotEmpty
          ? narrative.supervisorOperationalSummary
          : supervisorAssessment.operationalSummary,
      riskTrend: narrative.supervisorRiskTrend.isNotEmpty
          ? narrative.supervisorRiskTrend
          : supervisorAssessment.riskTrend,
      recommendations: narrative.supervisorRecommendations.isNotEmpty
          ? narrative.supervisorRecommendations
          : supervisorAssessment.recommendations,
    ),
    companyAchievements: narrative.companyAchievements.isNotEmpty
        ? CompanyAchievementsSnapshot(highlights: narrative.companyAchievements)
        : companyAchievements,
    emergingThreats: narrative.emergingThreats.isNotEmpty
        ? EmergingThreatSnapshot(patternsObserved: narrative.emergingThreats)
        : emergingThreats,
    narrativeRequest: narrativeRequest,
  );
}
```

**Import required** in `report_bundle.dart`:
```dart
import 'client_narrative_result.dart';
```

---

### 2.4 `ReportsWorkspaceAgent`

**File:** `lib/application/reports_workspace_agent.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/crm/reporting/client_narrative_result.dart';
import '../domain/crm/reporting/report_audience.dart';
import '../domain/crm/reporting/report_bundle.dart';
import 'onyx_claude_report_config.dart';

class ReportsWorkspaceAgent {
  static const String _endpoint =
      'https://api.anthropic.com/v1/messages';
  static const String _anthropicVersion = '2023-06-01';

  final OnyxClaudeReportConfig config;

  /// [httpClient] is injectable for unit testing with a fake HTTP client.
  /// Production code passes null and the agent creates its own client.
  final http.Client? httpClient;

  const ReportsWorkspaceAgent({
    required this.config,
    this.httpClient,
  });

  /// Generates a per-client narrative for [bundle] at the given [audience] tone.
  ///
  /// Returns null (never throws) on:
  ///   - unconfigured API key
  ///   - HTTP error (non-2xx)
  ///   - timeout
  ///   - malformed or incomplete JSON in the Claude response
  ///   - any unexpected exception
  ///
  /// Callers must treat null as "use template fallback."
  Future<ClientNarrativeResult?> generateNarrative({
    required ReportBundle bundle,
    required ReportAudience audience,
  }) async {
    if (!config.isConfigured) return null;

    final client = httpClient ?? http.Client();
    final generatedAt = DateTime.now().toUtc();

    try {
      final response = await client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': config.apiKey,
              'anthropic-version': _anthropicVersion,
            },
            body: jsonEncode({
              'model': config.model,
              'max_tokens': config.maxTokens,
              'system': _buildSystemPrompt(audience),
              'messages': [
                {'role': 'user', 'content': _buildUserPrompt(bundle)},
              ],
            }),
          )
          .timeout(Duration(seconds: config.timeoutSeconds));

      if (response.statusCode != 200) {
        // Caller is responsible for logging; agent returns null silently.
        return null;
      }

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>?;
      if (responseBody == null) return null;

      final usage = responseBody['usage'] as Map<String, dynamic>?;
      final inputTokens = (usage?['input_tokens'] as int?) ?? 0;
      final outputTokens = (usage?['output_tokens'] as int?) ?? 0;

      final contentList = responseBody['content'] as List<dynamic>?;
      final textBlock = contentList
          ?.whereType<Map<String, dynamic>>()
          .firstWhere(
            (b) => b['type'] == 'text',
            orElse: () => <String, dynamic>{},
          );
      final rawText = textBlock?['text']?.toString();
      if (rawText == null || rawText.isEmpty) return null;

      final Map<String, dynamic> narrativeJson;
      try {
        narrativeJson = jsonDecode(rawText) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }

      return ClientNarrativeResult.fromClaudeJson(
        narrativeJson,
        clientId: bundle.clientSnapshot.clientId,
        month: bundle.clientSnapshot.reportingPeriod,
        audience: audience,
        modelId: config.model,
        generatedAt: generatedAt,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      );
    } catch (_) {
      return null;
    } finally {
      if (httpClient == null) client.close();
    }
  }
}
```

---

## 3. Prompt Template

### 3.1 System prompt

```dart
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
```

### 3.2 User prompt

```dart
String _buildUserPrompt(ReportBundle bundle) {
  final sr = bundle.sceneReview;
  final pp = bundle.patrolPerformance;
  final mr = bundle.monthlyReport;
  final cs = bundle.clientSnapshot;

  final incidentLines = bundle.incidentDetails
      .take(5)
      .map((i) =>
          '  - [${i.riskCategory}] ${i.incidentId}'
          ' | SLA: ${i.slaResult}'
          '${i.overrideApplied ? ' (override applied)' : ''}')
      .join('\n');

  final guardCount = bundle.guardPerformance.length;
  final avgGuardCompliance = guardCount > 0
      ? bundle.guardPerformance
              .map((g) => g.compliancePercentage)
              .reduce((a, b) => a + b) /
          guardCount
      : 0.0;

  return '''
CLIENT: ${cs.clientName} | SITE: ${cs.siteName}
PERIOD: ${cs.reportingPeriod} | SLA TIER: ${cs.slaTier}

PERFORMANCE METRICS:
  Incidents total:         ${mr.totalIncidents}
  Escalations:             ${mr.totalEscalations}
  SLA compliance rate:     ${(mr.slaComplianceRate * 100).toStringAsFixed(1)}%
  SLA breaches:            ${mr.totalSlaBreaches}
  SLA overrides applied:   ${mr.totalSlaOverrides}
  Client contacts:         ${mr.totalClientContacts}

PATROL PERFORMANCE:
  Scheduled:               ${pp.scheduledPatrols}
  Completed:               ${pp.completedPatrols}
  Missed:                  ${pp.missedPatrols}
  Completion rate:         ${(pp.completionRate * 100).toStringAsFixed(1)}%

GUARD ROSTER:
  Guards on record:        $guardCount
  Average compliance:      ${avgGuardCompliance.toStringAsFixed(1)}%

SCENE REVIEW (AI-assisted):
  Total reviews:           ${sr.totalReviews}
  Model-reviewed:          ${sr.modelReviews}
  Suppressed actions:      ${sr.suppressedActions}
  Escalation candidates:   ${sr.escalationCandidates}
  Incident alerts:         ${sr.incidentAlerts}
  Dominant posture:        ${sr.topPosture}

INCIDENT LOG (latest ${bundle.incidentDetails.take(5).length}):
$incidentLines

Generate the four narrative sections as JSON only.
''';
}
```

### 3.3 Claude response example (expected shape)

```json
{
  "executiveSummary": {
    "headline": "Site maintained stable operations with 94.2% SLA compliance in March 2026.",
    "performanceSummary": "Seven incidents were recorded, of which two escalated to response dispatch. Guard compliance averaged 91% across three officers on record. No SLA overrides were applied.",
    "slaSummary": "SLA compliance reached 94.2% against a Premier tier target. One breach was recorded due to delayed response arrival on 2026-03-14.",
    "riskSummary": "Scene review identified three escalation candidates across 42 AI reviews. Dominant posture was 'low-activity', indicating stable overnight conditions."
  },
  "supervisorAssessment": {
    "operationalSummary": "Operations were stable. Patrol completion rate of 88% is within acceptable range but below the 95% target. The missed patrols occurred on weekend night shifts.",
    "riskTrend": "Risk posture is stable-to-improving. Suppressed action count dropped by two compared to prior period, indicating fewer false-positive triggers.",
    "recommendations": "Review weekend night patrol scheduling to close the 7% completion gap; conduct debrief on the 2026-03-14 SLA breach; consider increasing camera sensitivity threshold given low false-positive rate"
  },
  "companyAchievements": [
    "Zero missed client contact windows for the second consecutive month",
    "Scene review model covered 100% of overnight intelligence events"
  ],
  "emergingThreats": [
    "Repeat vehicle loitering pattern observed on Tuesdays between 02:00–04:00",
    "Two perimeter-adjacent incidents within 400m of site boundary in the past fortnight"
  ]
}
```

---

## 4. Error Handling Contract

### 4.1 What `ReportsWorkspaceAgent.generateNarrative()` guarantees

| Condition | Behaviour | Caller impact |
|---|---|---|
| `config.isConfigured == false` | Return `null` immediately, no network call | Template fallback used |
| HTTP status != 200 | Return `null`, no throw | Template fallback used |
| `http.post` times out (`TimeoutException`) | Return `null` (caught in outer `catch (_)`) | Template fallback used |
| `jsonDecode` fails on response body | Return `null` | Template fallback used |
| `jsonDecode` succeeds but `content` block absent | Return `null` | Template fallback used |
| `text` block present but `jsonDecode` of text fails | Return `null` (inner try/catch) | Template fallback used |
| Claude response JSON missing any top-level key | `ClientNarrativeResult.fromClaudeJson` returns `null` | Template fallback used |
| Any other uncaught exception | Caught by outer `catch (_)`, return `null` | Template fallback used |

**`ReportsWorkspaceAgent.generateNarrative()` never throws.** This is a hard contract.

### 4.2 What `ClientNarrativeResult.fromClaudeJson()` guarantees

- Returns `null` if `executiveSummary`, `supervisorAssessment`, `companyAchievements`, or `emergingThreats` are absent or wrong type.
- Accepts partial inner fields — individual missing string keys default to `''`. This tolerates Claude omitting a less-critical sub-field without discarding the entire result.
- Does not trim or validate prose content. The caller (PDF exporter) is responsible for rendering whatever string is provided.

### 4.3 What `ReportBundle.withNarrative()` guarantees

- Is a pure function. It never mutates `this`.
- If a `ClientNarrativeResult` field is an empty string, the existing template-generated value in `this` is preserved (see fall-through logic in section 2.3).
- If `narrative.companyAchievements` or `narrative.emergingThreats` are empty lists, the template snapshot is preserved unchanged.
- Does not validate that the narrative `clientId` or `month` match the bundle. Codex must ensure the caller passes the correct narrative for the correct bundle.

### 4.4 What the caller (`ReportGenerationService`) is responsible for

- Logging: the agent returns `null` silently. `ReportGenerationService` should log at debug level when `narrative == null` so that missed generations are observable without alerting.
- Not re-trying. The agent is one-shot per `generatePdfReport()` call. Retry logic is out of scope for Phase 1.
- Keeping the canonical hash based on the **template bundle** (before `withNarrative()`). See section 5.

---

## 5. Integration into `ReportGenerationService`

### 5.1 Method signature change

Add two optional named parameters to `generatePdfReport()`. All existing callers remain valid because both parameters have defaults.

```dart
Future<GeneratedReportResult> generatePdfReport({
  required String clientId,
  required String siteId,
  required DateTime nowUtc,
  ReportBrandingConfiguration brandingConfiguration =
      const ReportBrandingConfiguration(),
  ReportSectionConfiguration sectionConfiguration =
      const ReportSectionConfiguration(),
  String investigationContextKey = '',
  ReportsWorkspaceAgent? narrativeAgent,            // NEW — null = no AI generation
  ReportAudience audience = ReportAudience.client,  // NEW — defaults to client tone
}) async {
```

### 5.2 Pipeline insertion order

The current pipeline (condensed from `report_generation_service.dart:99–232`):

```
Step 1  ReportBundleAssembler.build(...)            → templateBundle
Step 2  ReportBundleCanonicalizer.canonicalJson(...) → canonicalJson
Step 3  sha256(canonicalJson)                       → canonicalHash
Step 4  PDFReportExporter.generate(templateBundle)  → pdfBytes
Step 5  new ReportGenerated(contentHash: canonicalHash, ...)
Step 6  store.append(receiptEvent)
```

**Modified pipeline (Phase 1 additions in caps):**

```
Step 1  ReportBundleAssembler.build(...)                        → templateBundle
Step 2  ReportBundleCanonicalizer.canonicalJson(templateBundle) → canonicalJson   ← UNCHANGED
Step 3  sha256(canonicalJson)                                   → canonicalHash   ← UNCHANGED
Step 1b IF narrativeAgent != null:
          await narrativeAgent.generateNarrative(
            bundle: templateBundle,
            audience: audience,
          )                                                      → narrative?      ← NEW
Step 1c final pdfBundle = narrative != null
            ? templateBundle.withNarrative(narrative)
            : templateBundle                                     → pdfBundle       ← NEW
Step 4  PDFReportExporter.generate(pdfBundle)                   → pdfBytes        ← USES pdfBundle
Step 5  new ReportGenerated(contentHash: canonicalHash, ...)                      ← UNCHANGED
Step 6  store.append(receiptEvent)                                                ← UNCHANGED
```

**Critical invariant:** The canonical hash is always computed from `templateBundle` (the assembler output before any AI injection). This means:

- `verifyReportHash()` continues to work without modification: it rebuilds the template bundle via `_buildBundleForReceipt()` and hashes it, matching the stored `contentHash`.
- `regenerateFromReceipt()` continues to produce a correct PDF from the template bundle. It will not include AI narrative because the receipt carries no narrative. This is acceptable for Phase 1 — AI-narrated receipt replay is a Phase 2.5 concern.
- The PDF carries AI narrative but the hash does not depend on it. A future `narrativeHash` field on `ReportGenerated` can be added when receipt-level narrative traceability is required.

### 5.3 Exact code delta for `generatePdfReport()`

Insert between the `bundle` assignment (current line ~167) and the `monthEvents` filter (current line ~169):

```dart
// --- Phase 1: AI narrative injection ---
final ClientNarrativeResult? narrative = narrativeAgent != null
    ? await narrativeAgent.generateNarrative(
        bundle: bundle,
        audience: audience,
      )
    : null;
final pdfBundle =
    narrative != null ? bundle.withNarrative(narrative) : bundle;
// ----------------------------------------
```

Then replace the single `PDFReportExporter.generate(bundle)` call (current line ~195) with:

```dart
final pdfBytes = await PDFReportExporter.generate(pdfBundle);
```

All other lines in `generatePdfReport()` remain unchanged. The `bundle` variable (template-based) continues to feed `canonicalJson`, `canonicalHash`, and `receiptEvent` construction. Only the PDF exporter receives `pdfBundle`.

### 5.4 Constructor change to `ReportGenerationService`

No constructor change is needed. `ReportsWorkspaceAgent` is passed per call, not injected into the service. This keeps the service free of a live network dependency at construction time and allows callers to pass or omit the agent per generation context.

---

## 6. Required Import for `ReportGenerationService`

```dart
import 'reports_workspace_agent.dart';
import '../domain/crm/reporting/client_narrative_result.dart';
import '../domain/crm/reporting/report_audience.dart';
```

`ReportAudience` import may already exist elsewhere in the file — Codex to check before adding.

---

## 7. Unit Test Surface (for Codex to implement alongside Phase 1)

These tests belong in `test/` and are out of scope for this spec to implement — listed here as the coverage contract Codex must satisfy before Phase 1 is considered complete.

### `onyx_claude_report_config_test.dart`
- `fromEnv` with all keys present → fields match
- `fromEnv` with empty map → defaults used, `isConfigured == false`
- `fromEnv` with malformed int values → defaults used without throwing

### `client_narrative_result_test.dart`
- `fromClaudeJson` with valid full JSON → all fields parsed correctly
- `fromClaudeJson` with missing `supervisorAssessment` key → returns null
- `fromClaudeJson` with `companyAchievements` as non-list → returns null
- `fromClaudeJson` with empty strings for inner fields → empty strings preserved (not null)
- `fallback` factory → `modelId == 'fallback'`, all prose is empty, lists are empty

### `report_bundle_with_narrative_test.dart`
- `withNarrative` with a full result → all six target fields replaced
- `withNarrative` with empty strings → original template fields preserved (fall-through)
- `withNarrative` is pure — original bundle unchanged after call

### `reports_workspace_agent_test.dart`
- `generateNarrative` with `isConfigured == false` → returns null, no HTTP call made
- `generateNarrative` with HTTP 401 → returns null
- `generateNarrative` with HTTP 200 and valid JSON → returns `ClientNarrativeResult`
- `generateNarrative` with HTTP 200 and non-JSON text block → returns null
- `generateNarrative` with HTTP 200 and JSON missing `emergingThreats` → returns null
- `generateNarrative` when `http.post` throws `TimeoutException` → returns null

---

## 8. Open Decision (Carry-Forward from Build Plan)

**DECISION — Gap 1:** The build plan recommends raw `http` calls over `anthropic_sdk_dart`. This spec implements raw HTTP (section 2.4 uses `package:http`). `http: ^1.5.0` is already in `pubspec.yaml`. If Zaks decides to use `anthropic_sdk_dart` instead, sections 2.4 and 7 must be revised before Codex implements.

**Recommendation:** Stay with raw HTTP for Phase 1. The Anthropic messages API is stable and the response shape is simple enough to parse without a client library. This avoids a new pub dependency and keeps the HTTP client injectable for testing.

---

## Handoff Checklist for Codex

- [ ] Create `lib/application/onyx_claude_report_config.dart` per section 2.1
- [ ] Create `lib/domain/crm/reporting/client_narrative_result.dart` per section 2.2
- [ ] Add `withNarrative()` to `ReportBundle` per section 2.3 (add `client_narrative_result.dart` import)
- [ ] Create `lib/application/reports_workspace_agent.dart` per section 2.4
- [ ] Extend `config/onyx.local.example.json` with the four `ONYX_CLAUDE_*` keys per section 2.1
- [ ] Modify `ReportGenerationService.generatePdfReport()` per sections 5.1–5.3
- [ ] Add required imports to `report_generation_service.dart` per section 6
- [ ] Implement unit tests listed in section 7
- [ ] Confirm `DECISION` in section 8 with Zaks before proceeding
