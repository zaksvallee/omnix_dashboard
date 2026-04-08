import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../domain/authority/onyx_task_protocol.dart';

enum OnyxAgentCloudIntent {
  camera,
  telemetry,
  patrol,
  client,
  report,
  correlation,
  dispatch,
  admin,
  general,
}

/// Routing tier for a given intent.
///
/// [local] — handled by the on-device Ollama model (fast, offline-safe):
///   general Q&A, summaries, short classifications, patrol checks, telemetry.
///
/// [cloud] — routed to the cloud provider (OpenAI / Claude) when available:
///   report generation, complex correlation, multi-step dispatch reasoning.
enum OnyxAgentRoutingTier { local, cloud }

/// Returns the preferred inference tier for a given [intent].
/// Callers may still fall back to local if the cloud service is unconfigured.
OnyxAgentRoutingTier onyxAgentRoutingTierFor(OnyxAgentCloudIntent intent) {
  return switch (intent) {
    // Fast, low-context tasks — well-suited to local inference.
    OnyxAgentCloudIntent.general => OnyxAgentRoutingTier.local,
    OnyxAgentCloudIntent.telemetry => OnyxAgentRoutingTier.local,
    OnyxAgentCloudIntent.patrol => OnyxAgentRoutingTier.local,
    OnyxAgentCloudIntent.camera => OnyxAgentRoutingTier.local,
    // High-complexity tasks — prefer cloud for quality and context window.
    OnyxAgentCloudIntent.report => OnyxAgentRoutingTier.cloud,
    OnyxAgentCloudIntent.correlation => OnyxAgentRoutingTier.cloud,
    OnyxAgentCloudIntent.dispatch => OnyxAgentRoutingTier.cloud,
    OnyxAgentCloudIntent.client => OnyxAgentRoutingTier.cloud,
    OnyxAgentCloudIntent.admin => OnyxAgentRoutingTier.cloud,
  };
}

/// Applies the ONYX smart-routing overrides on top of the base intent tier.
///
/// Long prompts and materially overdue follow-ups are escalated to cloud when
/// the caller has cloud capacity available; otherwise callers can still fall
/// back to local at execution time.
OnyxAgentRoutingTier onyxAgentSmartRoutingTierFor({
  required OnyxAgentCloudIntent intent,
  required String prompt,
  int pendingFollowUpAgeMinutes = 0,
}) {
  if (prompt.trim().length > 400 || pendingFollowUpAgeMinutes > 60) {
    return OnyxAgentRoutingTier.cloud;
  }
  return onyxAgentRoutingTierFor(intent);
}

class OnyxAgentCloudScope {
  final String clientId;
  final String siteId;
  final String incidentReference;
  final String sourceRouteLabel;
  final bool operatorFocusPreserved;
  final String operatorFocusThreadTitle;
  final String operatorFocusUrgentThreadTitle;
  final String pendingFollowUpLabel;
  final String pendingFollowUpPrompt;
  final OnyxToolTarget? pendingFollowUpTarget;
  final String pendingFollowUpStatus;
  final int pendingFollowUpAgeMinutes;
  final int pendingFollowUpReopenCycles;
  final List<String> pendingConfirmations;

  const OnyxAgentCloudScope({
    this.clientId = '',
    this.siteId = '',
    this.incidentReference = '',
    this.sourceRouteLabel = 'Command',
    this.operatorFocusPreserved = false,
    this.operatorFocusThreadTitle = '',
    this.operatorFocusUrgentThreadTitle = '',
    this.pendingFollowUpLabel = '',
    this.pendingFollowUpPrompt = '',
    this.pendingFollowUpTarget,
    this.pendingFollowUpStatus = '',
    this.pendingFollowUpAgeMinutes = 0,
    this.pendingFollowUpReopenCycles = 0,
    this.pendingConfirmations = const <String>[],
  });

  bool get hasPendingFollowUp {
    return pendingFollowUpLabel.trim().isNotEmpty &&
        pendingFollowUpPrompt.trim().isNotEmpty &&
        pendingFollowUpTarget != null;
  }

  bool get hasOperatorFocusContext => operatorFocusPreserved;
}

class OnyxAgentBrainAdvisory {
  final String summary;
  final OnyxToolTarget? recommendedTarget;
  final double? confidence;
  final String why;
  final List<String> missingInfo;
  final String primaryPressure;
  final List<String> contextHighlights;
  final String operatorFocusNote;
  final String followUpLabel;
  final String followUpPrompt;
  final String followUpStatus;
  final String narrative;

  const OnyxAgentBrainAdvisory({
    required this.summary,
    required this.recommendedTarget,
    required this.confidence,
    required this.why,
    required this.missingInfo,
    this.primaryPressure = '',
    this.contextHighlights = const <String>[],
    this.operatorFocusNote = '',
    this.followUpLabel = '',
    this.followUpPrompt = '',
    this.followUpStatus = '',
    required this.narrative,
  });

  OnyxAgentBrainAdvisory copyWith({
    String? summary,
    OnyxToolTarget? recommendedTarget,
    double? confidence,
    String? why,
    List<String>? missingInfo,
    String? primaryPressure,
    List<String>? contextHighlights,
    String? operatorFocusNote,
    String? followUpLabel,
    String? followUpPrompt,
    String? followUpStatus,
    String? narrative,
  }) {
    return OnyxAgentBrainAdvisory(
      summary: summary ?? this.summary,
      recommendedTarget: recommendedTarget ?? this.recommendedTarget,
      confidence: confidence ?? this.confidence,
      why: why ?? this.why,
      missingInfo: missingInfo ?? List<String>.from(this.missingInfo),
      primaryPressure: primaryPressure ?? this.primaryPressure,
      contextHighlights:
          contextHighlights ?? List<String>.from(this.contextHighlights),
      operatorFocusNote: operatorFocusNote ?? this.operatorFocusNote,
      followUpLabel: followUpLabel ?? this.followUpLabel,
      followUpPrompt: followUpPrompt ?? this.followUpPrompt,
      followUpStatus: followUpStatus ?? this.followUpStatus,
      narrative: narrative ?? this.narrative,
    );
  }
}

extension OnyxAgentBrainAdvisoryCommandBodyLines on OnyxAgentBrainAdvisory {
  List<String> commandBodySupportLines({
    String? primaryPressureLine,
    String? operatorFocusLine,
    String? recommendedDeskLabel,
    List<String> orderedContextHighlights = const <String>[],
  }) {
    return <String>[
      if (summary.trim().isNotEmpty) 'Summary: ${summary.trim()}',
      ?primaryPressureLine,
      ?operatorFocusLine,
      ?(recommendedDeskLabel == null
          ? null
          : 'Recommended desk: $recommendedDeskLabel'),
      if (why.trim().isNotEmpty) 'Why: ${why.trim()}',
      if (orderedContextHighlights.isNotEmpty)
        'Context: ${orderedContextHighlights.join(' | ')}',
    ];
  }

  List<String> commandBodyClosingLines({String? confidenceLabel}) {
    final trimmedFollowUpLabel = followUpLabel.trim();
    final trimmedFollowUpStatus = followUpStatus.trim();
    return <String>[
      if (confidenceLabel != null && confidenceLabel.trim().isNotEmpty)
        'Confidence: ${confidenceLabel.trim()}',
      if (missingInfo.isNotEmpty) 'Missing info: ${missingInfo.join(', ')}',
      if (trimmedFollowUpLabel.isNotEmpty)
        trimmedFollowUpStatus.isEmpty
            ? 'Next follow-up: $trimmedFollowUpLabel'
            : 'Next follow-up: $trimmedFollowUpLabel ($trimmedFollowUpStatus)',
    ];
  }

  List<String> commandBodyFooterLines({
    required String responseText,
    required String providerLabel,
  }) {
    final trimmedResponseText = responseText.trim();
    return <String>[
      if (trimmedResponseText.isNotEmpty &&
          trimmedResponseText != summary.trim() &&
          trimmedResponseText != why.trim())
        'Narrative: $trimmedResponseText',
      'Source: ${providerLabel.trim()}',
    ];
  }
}

class OnyxAgentCloudBoostResponse {
  final String text;
  final String providerLabel;
  final OnyxAgentBrainAdvisory? advisory;
  final bool isError;
  final String errorSummary;
  final String errorDetail;

  const OnyxAgentCloudBoostResponse({
    required this.text,
    required this.providerLabel,
    this.advisory,
    this.isError = false,
    this.errorSummary = '',
    this.errorDetail = '',
  });
}

OnyxAgentCloudBoostResponse onyxAgentCloudBoostResponseFromRawText({
  required String rawText,
  required String providerLabel,
}) {
  final cleanedText = rawText.trim();
  final advisory = _tryParseBrainAdvisory(cleanedText);
  return OnyxAgentCloudBoostResponse(
    text: advisory?.narrative.trim().isNotEmpty == true
        ? advisory!.narrative.trim()
        : cleanedText,
    providerLabel: providerLabel,
    advisory: advisory,
  );
}

OnyxAgentCloudBoostResponse onyxAgentCloudBoostErrorResponse({
  required String providerLabel,
  required String errorSummary,
  required String errorDetail,
}) {
  return OnyxAgentCloudBoostResponse(
    text: '',
    providerLabel: providerLabel,
    isError: true,
    errorSummary: errorSummary.trim(),
    errorDetail: errorDetail.trim(),
  );
}

abstract class OnyxAgentCloudBoostService {
  bool get isConfigured;

  Future<OnyxAgentCloudBoostResponse?> boost({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  });
}

class UnconfiguredOnyxAgentCloudBoostService
    implements OnyxAgentCloudBoostService {
  const UnconfiguredOnyxAgentCloudBoostService();

  @override
  bool get isConfigured => false;

  @override
  Future<OnyxAgentCloudBoostResponse?> boost({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    return null;
  }
}

class OpenAiOnyxAgentCloudBoostService implements OnyxAgentCloudBoostService {
  final http.Client client;
  final String apiKey;
  final String model;
  final Uri endpoint;
  final Duration requestTimeout;

  OpenAiOnyxAgentCloudBoostService({
    required this.client,
    required this.apiKey,
    required this.model,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 18),
  }) : endpoint = endpoint ?? Uri.parse('https://api.openai.com/v1/responses');

  @override
  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  @override
  Future<OnyxAgentCloudBoostResponse?> boost({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    final cleanedPrompt = prompt.trim();
    final providerLabel = 'openai:${model.trim()}';
    if (!isConfigured || cleanedPrompt.isEmpty) {
      return null;
    }

    try {
      final response = await client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': model.trim(),
              'temperature': 0.2,
              'max_output_tokens': 512,
              'input': [
                {
                  'role': 'system',
                  'content': [
                    {
                      'type': 'input_text',
                      'text': _systemPrompt(scope: scope, intent: intent),
                    },
                    if (scope.hasPendingFollowUp)
                      {
                        'type': 'input_text',
                        'text': onyxAgentPendingFollowUpContextForScope(scope),
                      },
                    if (scope.hasOperatorFocusContext)
                      {
                        'type': 'input_text',
                        'text': onyxAgentOperatorFocusContextForScope(scope),
                      },
                    if (contextSummary.trim().isNotEmpty)
                      {
                        'type': 'input_text',
                        'text': 'Operational context: ${contextSummary.trim()}',
                      },
                  ],
                },
                {
                  'role': 'user',
                  'content': [
                    {'type': 'input_text', 'text': cleanedPrompt},
                  ],
                },
              ],
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return onyxAgentCloudBoostErrorResponse(
          providerLabel: providerLabel,
          errorSummary: 'OpenAI brain request failed',
          errorDetail: 'Provider returned HTTP ${response.statusCode}.',
        );
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (error) {
        developer.log(
          'Cloud boost response JSON was invalid.',
          name: 'OnyxAgentCloudBoostService',
          error: error,
        );
        return onyxAgentCloudBoostErrorResponse(
          providerLabel: providerLabel,
          errorSummary: 'OpenAI brain response was invalid',
          errorDetail:
              'Provider returned a response that could not be parsed as JSON.',
        );
      }
      final text = _extractText(decoded);
      if (text == null || text.trim().isEmpty) {
        return null;
      }
      final rawResponse = onyxAgentCloudBoostResponseFromRawText(
        rawText: text.trim(),
        providerLabel: providerLabel,
      );
      return onyxAgentMergePlannerMaintenancePriorityHighlight(
        response: rawResponse,
        scope: scope,
        contextSummary: contextSummary,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Cloud boost request failed.',
        name: 'OnyxAgentCloudBoostService',
        error: error,
        stackTrace: stackTrace,
      );
      return onyxAgentCloudBoostErrorResponse(
        providerLabel: providerLabel,
        errorSummary: 'OpenAI brain request failed',
        errorDetail: '${error.runtimeType}: $error',
      );
    }
  }

  String _systemPrompt({
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
  }) {
    final clientId = scope.clientId.trim().isEmpty
        ? 'global'
        : scope.clientId.trim();
    final siteId = scope.siteId.trim().isEmpty
        ? 'all-sites'
        : scope.siteId.trim();
    final incident = scope.incidentReference.trim().isEmpty
        ? 'none'
        : scope.incidentReference.trim();
    final route = scope.sourceRouteLabel.trim().isEmpty
        ? 'Command'
        : scope.sourceRouteLabel.trim();
    return 'You are ONYX Intelligence, an AI assistant embedded in a private security and intelligence operations platform. '
        'You assist operators, guards, and analysts with operational decisions, threat assessment, incident logging, and client management. '
        'Be direct, precise, and professional. Never fabricate data. If uncertain, say so.\n'
        'Route origin: $route.\n'
        'Internal scope: client=$clientId site=$siteId incident=$incident.\n'
        'Intent lane: ${intent.name}.\n'
        'Rules:\n'
        '1) Be concise, practical, and calm.\n'
        '2) Do not invent device writes, dispatches, ETAs, arrivals, or completed outcomes.\n'
        '3) Keep execution local-first and approval-gated.\n'
        '4) Never ask for or repeat passwords, bearer tokens, or secret credentials.\n'
        '5) Focus on what a controller should understand next, not on implementation details.\n'
        '6) Preferred output is compact JSON with keys summary, recommended_target, confidence, why, missing_info, primary_pressure, context_highlights, operator_focus_note, follow_up_label, follow_up_prompt, follow_up_status, text.\n'
        '7) Use recommended_target only as one of dispatchBoard, tacticalTrack, cctvReview, clientComms, reportsWorkspace.\n'
        '8) If JSON is not possible, return plain text only with no markdown bullets.\n'
        '9) Keep the answer to two short paragraphs max when returning plain text.\n'
        '10) If the request is ambiguous, make the safest helpful inference and say what still needs confirmation.\n'
        '11) If an outstanding thread follow-up is marked unresolved or overdue, keep that checkpoint warm unless a stronger human-safety signal outranks it.\n'
        '12) Use follow_up_status only as one of pending, unresolved, overdue, cleared.\n'
        '13) If operator focus is preserved on the current thread, respect that manual context and explain any urgent review elsewhere without changing the desk recommendation unless safety clearly requires it.\n'
        '14) If operational context includes a primary pressure, echo it in primary_pressure using one of planner maintenance, overdue follow-up, unresolved follow-up, operator focus hold, or active signal watch.\n'
        '15) If operational context includes a planner maintenance priority, echo that pressure as a short first context_highlights item when it materially affects the next step.';
  }
}

OnyxAgentCloudBoostResponse onyxAgentMergePlannerMaintenancePriorityHighlight({
  required OnyxAgentCloudBoostResponse response,
  required OnyxAgentCloudScope scope,
  required String contextSummary,
}) {
  final advisory = response.advisory;
  if (advisory == null) {
    return response;
  }
  final mergedPrimaryPressure = advisory.primaryPressure.trim().isNotEmpty
      ? advisory.primaryPressure.trim()
      : (onyxAgentPrimaryPressureFromContextSummary(contextSummary) ??
            onyxAgentPrimaryPressureFromScope(scope));
  final mergedHighlights = onyxAgentPrioritizedContextHighlights(
    currentHighlights: advisory.contextHighlights,
    scope: scope,
    contextSummary: contextSummary,
    operatorFocusNote: advisory.operatorFocusNote,
  );
  if (_sameNormalizedHighlights(mergedHighlights, advisory.contextHighlights) &&
      mergedPrimaryPressure == advisory.primaryPressure.trim()) {
    return response;
  }
  return OnyxAgentCloudBoostResponse(
    text: response.text,
    providerLabel: response.providerLabel,
    advisory: advisory.copyWith(
      primaryPressure: mergedPrimaryPressure,
      contextHighlights: mergedHighlights,
    ),
    isError: response.isError,
    errorSummary: response.errorSummary,
    errorDetail: response.errorDetail,
  );
}

List<String> onyxAgentPrioritizedContextHighlights({
  required List<String> currentHighlights,
  required OnyxAgentCloudScope scope,
  required String contextSummary,
  String operatorFocusNote = '',
}) {
  final remaining = currentHighlights
      .map((highlight) => highlight.trim())
      .where((highlight) => highlight.isNotEmpty)
      .toList(growable: true);
  final ordered = <String>[];

  final canonicalByCategory = <_OnyxAgentPriorityHighlightCategory, String?>{
    _OnyxAgentPriorityHighlightCategory.maintenance:
        onyxAgentPlannerMaintenancePriorityHighlightFromContextSummary(
          contextSummary,
        ),
    _OnyxAgentPriorityHighlightCategory.overdueFollowUp:
        onyxAgentPendingFollowUpPriorityHighlightForScope(
          scope,
          status: 'overdue',
        ),
    _OnyxAgentPriorityHighlightCategory.unresolvedFollowUp:
        onyxAgentPendingFollowUpPriorityHighlightForScope(
          scope,
          status: 'unresolved',
        ),
    _OnyxAgentPriorityHighlightCategory.operatorFocus:
        onyxAgentOperatorFocusPriorityHighlightForScope(
          scope,
          operatorFocusNote: operatorFocusNote,
        ),
  };

  for (final category in const <_OnyxAgentPriorityHighlightCategory>[
    _OnyxAgentPriorityHighlightCategory.maintenance,
    _OnyxAgentPriorityHighlightCategory.overdueFollowUp,
    _OnyxAgentPriorityHighlightCategory.unresolvedFollowUp,
    _OnyxAgentPriorityHighlightCategory.operatorFocus,
  ]) {
    final existingIndex = remaining.indexWhere(
      (highlight) => _priorityHighlightCategory(highlight) == category,
    );
    if (existingIndex >= 0) {
      final existingHighlight = remaining.removeAt(existingIndex);
      if (!_containsNormalizedHighlight(ordered, existingHighlight)) {
        ordered.add(existingHighlight);
      }
      continue;
    }
    final canonicalHighlight = canonicalByCategory[category];
    if (canonicalHighlight == null || canonicalHighlight.isEmpty) {
      continue;
    }
    if (_containsNormalizedHighlight(ordered, canonicalHighlight) ||
        _containsNormalizedHighlight(remaining, canonicalHighlight)) {
      continue;
    }
    ordered.add(canonicalHighlight);
  }

  for (final highlight in remaining) {
    if (_containsNormalizedHighlight(ordered, highlight)) {
      continue;
    }
    ordered.add(highlight);
  }
  return ordered;
}

String? onyxAgentPlannerMaintenancePriorityHighlightFromContextSummary(
  String contextSummary,
) {
  const marker = 'Planner maintenance priority:';
  final normalizedSummary = contextSummary.trim();
  if (normalizedSummary.isEmpty) {
    return null;
  }
  final start = normalizedSummary.indexOf(marker);
  if (start < 0) {
    return null;
  }
  var detail = normalizedSummary.substring(start + marker.length).trim();
  for (final boundary in const <String>[
    ' Planner maintenance alert:',
    ' Planner reactivation:',
    ' Planner backlog item:',
    ' Planner tuning cue:',
    ' Planner review signal:',
    ' Operator focus preserved',
  ]) {
    final boundaryIndex = detail.indexOf(boundary);
    if (boundaryIndex >= 0) {
      detail = detail.substring(0, boundaryIndex).trim();
    }
  }
  if (detail.isEmpty) {
    return null;
  }
  final firstSentenceIndex = detail.indexOf('. ');
  final sentence = firstSentenceIndex >= 0
      ? detail.substring(0, firstSentenceIndex).trim()
      : detail.trim().replaceFirst(RegExp(r'[.]+$'), '');
  if (sentence.isEmpty) {
    return null;
  }
  return 'Top maintenance pressure: ${_withTerminalPeriod(sentence)}';
}

String? onyxAgentPrimaryPressureFromContextSummary(String contextSummary) {
  final primaryPressure = _pressureLabelFromContextSummary(
    contextSummary,
    marker: 'Primary pressure:',
  );
  if (primaryPressure != null) {
    return primaryPressure;
  }
  final threadMemoryPressure = _pressureLabelFromContextSummary(
    contextSummary,
    marker: 'Thread memory primary pressure:',
  );
  if (threadMemoryPressure != null) {
    return threadMemoryPressure;
  }
  if (onyxAgentPlannerMaintenancePriorityHighlightFromContextSummary(
        contextSummary,
      ) !=
      null) {
    return 'planner maintenance';
  }
  return null;
}

String? onyxAgentPrimaryPressureFromScope(OnyxAgentCloudScope scope) {
  final normalizedStatus = scope.pendingFollowUpStatus.trim().toLowerCase();
  if (scope.hasPendingFollowUp) {
    if (normalizedStatus == 'overdue') {
      return 'overdue follow-up';
    }
    if (normalizedStatus == 'unresolved') {
      return 'unresolved follow-up';
    }
  }
  if (scope.hasOperatorFocusContext) {
    return 'operator focus hold';
  }
  return null;
}

String? onyxAgentPendingFollowUpPriorityHighlightForScope(
  OnyxAgentCloudScope scope, {
  required String status,
}) {
  if (!scope.hasPendingFollowUp) {
    return null;
  }
  final normalizedStatus = scope.pendingFollowUpStatus.trim().toLowerCase();
  if (normalizedStatus != status) {
    return null;
  }
  final label = scope.pendingFollowUpLabel.trim();
  if (label.isEmpty) {
    return null;
  }
  return 'Outstanding follow-up: $label ($normalizedStatus).';
}

String? onyxAgentOperatorFocusPriorityHighlightForScope(
  OnyxAgentCloudScope scope, {
  String operatorFocusNote = '',
}) {
  if (!scope.hasOperatorFocusContext) {
    return null;
  }
  final note = operatorFocusNote.trim();
  if (note.isNotEmpty) {
    return 'Operator focus preserved: ${_withTerminalPeriod(note)}';
  }
  final currentThread = scope.operatorFocusThreadTitle.trim().isEmpty
      ? 'current thread'
      : scope.operatorFocusThreadTitle.trim();
  final urgentThread = scope.operatorFocusUrgentThreadTitle.trim();
  if (urgentThread.isNotEmpty) {
    return 'Operator focus preserved: manual context preserved on $currentThread while urgent review remains visible on $urgentThread.';
  }
  return 'Operator focus preserved: manual context preserved on $currentThread until the operator changes threads.';
}

String onyxAgentPendingFollowUpContextForScope(OnyxAgentCloudScope scope) {
  final target = scope.pendingFollowUpTarget?.name ?? 'unknown';
  final confirmations = scope.pendingConfirmations
      .where((entry) => entry.trim().isNotEmpty)
      .join(', ');
  final parts = <String>[
    'Outstanding thread follow-up:',
    'status=${scope.pendingFollowUpStatus.trim().isEmpty ? 'pending' : scope.pendingFollowUpStatus.trim()}',
    'desk=$target',
    'label=${scope.pendingFollowUpLabel.trim()}',
    'age_minutes=${scope.pendingFollowUpAgeMinutes}',
    'reopen_cycles=${scope.pendingFollowUpReopenCycles}',
  ];
  if (confirmations.isNotEmpty) {
    parts.add('still_confirm=$confirmations');
  }
  return parts.join(' ');
}

String _withTerminalPeriod(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  return trimmed.endsWith('.') ? trimmed : '$trimmed.';
}

String? _pressureLabelFromContextSummary(
  String contextSummary, {
  required String marker,
}) {
  final normalizedSummary = contextSummary.trim();
  if (normalizedSummary.isEmpty) {
    return null;
  }
  final start = normalizedSummary.indexOf(marker);
  if (start < 0) {
    return null;
  }
  var detail = normalizedSummary.substring(start + marker.length).trim();
  final sentenceBreak = detail.indexOf('. ');
  if (sentenceBreak >= 0) {
    detail = detail.substring(0, sentenceBreak).trim();
  }
  final normalized = detail.replaceFirst(RegExp(r'[.]+$'), '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized.toLowerCase();
}

String _normalizeHighlight(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _containsNormalizedHighlight(List<String> highlights, String candidate) {
  final normalizedCandidate = _normalizeHighlight(candidate);
  return highlights.any((highlight) {
    return _normalizeHighlight(highlight) == normalizedCandidate;
  });
}

bool _sameNormalizedHighlights(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (_normalizeHighlight(left[index]) != _normalizeHighlight(right[index])) {
      return false;
    }
  }
  return true;
}

enum _OnyxAgentPriorityHighlightCategory {
  maintenance,
  overdueFollowUp,
  unresolvedFollowUp,
  operatorFocus,
  other,
}

_OnyxAgentPriorityHighlightCategory _priorityHighlightCategory(
  String highlight,
) {
  final normalized = _normalizeHighlight(highlight);
  if (normalized.startsWith('top maintenance pressure') ||
      normalized.startsWith('maintenance alert') ||
      normalized.contains('chronic drift')) {
    return _OnyxAgentPriorityHighlightCategory.maintenance;
  }
  if (normalized.startsWith('outstanding follow up')) {
    if (normalized.contains('overdue')) {
      return _OnyxAgentPriorityHighlightCategory.overdueFollowUp;
    }
    if (normalized.contains('unresolved')) {
      return _OnyxAgentPriorityHighlightCategory.unresolvedFollowUp;
    }
  }
  if (normalized.startsWith('operator focus preserved') ||
      normalized.contains('manual context preserved') ||
      normalized.contains('urgent review remains visible')) {
    return _OnyxAgentPriorityHighlightCategory.operatorFocus;
  }
  return _OnyxAgentPriorityHighlightCategory.other;
}

String onyxAgentOperatorFocusContextForScope(OnyxAgentCloudScope scope) {
  final currentThread = scope.operatorFocusThreadTitle.trim().isEmpty
      ? 'current thread'
      : scope.operatorFocusThreadTitle.trim();
  final urgentThread = scope.operatorFocusUrgentThreadTitle.trim();
  final parts = <String>[
    'Operator-preserved thread context:',
    'current_thread=$currentThread',
    'state=manual_context_preserved',
  ];
  if (urgentThread.isNotEmpty) {
    parts.add('urgent_review_thread=$urgentThread');
    parts.add('reason=manual context preserved over urgent review');
  } else {
    parts.add('reason=manual context preserved until operator changes threads');
  }
  return parts.join(' ');
}

String? _extractText(Object? decoded) {
  if (decoded is! Map) {
    return null;
  }
  final map = decoded.cast<Object?, Object?>();
  final outputText = map['output_text'];
  if (outputText is String && outputText.trim().isNotEmpty) {
    return outputText.trim();
  }
  final output = map['output'];
  if (output is List) {
    final chunks = <String>[];
    for (final item in output) {
      if (item is! Map) {
        continue;
      }
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final part in content) {
        if (part is! Map) {
          continue;
        }
        final text = (part['text'] ?? '').toString().trim();
        if (text.isNotEmpty) {
          chunks.add(text);
        }
      }
    }
    if (chunks.isNotEmpty) {
      return chunks.join('\n').trim();
    }
  }
  final choices = map['choices'];
  if (choices is List && choices.isNotEmpty) {
    final first = choices.first;
    if (first is Map) {
      final message = first['message'];
      if (message is Map) {
        final content = (message['content'] ?? '').toString().trim();
        if (content.isNotEmpty) {
          return content;
        }
      }
    }
  }
  return null;
}

OnyxAgentBrainAdvisory? _tryParseBrainAdvisory(String rawText) {
  final candidate = _extractJsonCandidate(rawText);
  if (candidate == null || candidate.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(candidate);
    if (decoded is! Map) {
      return null;
    }
    final map = decoded.cast<Object?, Object?>();
    final summary = _stringFromValue(
      map['summary'] ?? map['headline'] ?? map['recommendation_summary'],
    );
    final recommendedTarget = _toolTargetFromValue(
      map['recommended_target'] ?? map['recommendedTarget'] ?? map['target'],
    );
    final confidence = _confidenceFromValue(map['confidence']);
    final why = _joinedStringFromValue(
      map['why'] ?? map['reason'] ?? map['rationale'],
    );
    final missingInfo = _listFromValue(
      map['missing_info'] ?? map['missingInfo'] ?? map['follow_up_needed'],
    );
    final primaryPressure = _stringFromValue(
      map['primary_pressure'] ??
          map['primaryPressure'] ??
          map['primary_pressure_label'] ??
          map['primaryPressureLabel'],
    );
    final contextHighlights = _listFromValue(
      map['context_highlights'] ?? map['contextHighlights'],
    );
    final operatorFocusNote = _stringFromValue(
      map['operator_focus_note'] ??
          map['operatorFocusNote'] ??
          map['manual_context_note'] ??
          map['manualContextNote'],
    );
    final followUpLabel = _stringFromValue(
      map['follow_up_label'] ??
          map['followUpLabel'] ??
          map['next_follow_up_label'] ??
          map['nextFollowUpLabel'],
    );
    final followUpPrompt = _stringFromValue(
      map['follow_up_prompt'] ??
          map['followUpPrompt'] ??
          map['next_follow_up_prompt'] ??
          map['nextFollowUpPrompt'],
    );
    final followUpStatus = _stringFromValue(
      map['follow_up_status'] ??
          map['followUpStatus'] ??
          map['pending_follow_up_status'] ??
          map['pendingFollowUpStatus'],
    );
    final narrative = _stringFromValue(
      map['text'] ?? map['narrative'] ?? map['plain_text'],
    );
    if (summary.isEmpty &&
        recommendedTarget == null &&
        why.isEmpty &&
        missingInfo.isEmpty &&
        primaryPressure.isEmpty &&
        contextHighlights.isEmpty &&
        operatorFocusNote.isEmpty &&
        followUpLabel.isEmpty &&
        followUpPrompt.isEmpty &&
        followUpStatus.isEmpty &&
        narrative.isEmpty) {
      return null;
    }
    return OnyxAgentBrainAdvisory(
      summary: summary,
      recommendedTarget: recommendedTarget,
      confidence: confidence,
      why: why,
      missingInfo: missingInfo,
      primaryPressure: primaryPressure,
      contextHighlights: contextHighlights,
      operatorFocusNote: operatorFocusNote,
      followUpLabel: followUpLabel,
      followUpPrompt: followUpPrompt,
      followUpStatus: followUpStatus,
      narrative: _buildNarrative(
        rawText: rawText,
        summary: summary,
        why: why,
        missingInfo: missingInfo,
        narrative: narrative,
      ),
    );
  } catch (error, stackTrace) {
    developer.log(
      'Unable to parse ONYX brain advisory payload.',
      name: 'OnyxAgentCloudBoostService',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

String? _extractJsonCandidate(String rawText) {
  final cleaned = rawText.trim();
  if (cleaned.isEmpty) {
    return null;
  }
  if (cleaned.startsWith('```')) {
    final lines = cleaned.split('\n');
    if (lines.length >= 3) {
      final body = lines.sublist(1, lines.length - 1).join('\n').trim();
      if (body.startsWith('{') && body.endsWith('}')) {
        return body;
      }
    }
  }
  if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
    return cleaned;
  }
  final start = cleaned.indexOf('{');
  final end = cleaned.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return cleaned.substring(start, end + 1);
  }
  return null;
}

String _stringFromValue(Object? value) {
  if (value == null) {
    return '';
  }
  return value.toString().trim();
}

String _joinedStringFromValue(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is List) {
    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .join(' ')
        .trim();
  }
  return value.toString().trim();
}

List<String> _listFromValue(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is List) {
    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return const <String>[];
  }
  return <String>[text];
}

double? _confidenceFromValue(Object? value) {
  if (value == null) {
    return null;
  }
  final numeric = switch (value) {
    int number => number.toDouble(),
    double number => number,
    String text => double.tryParse(text.trim()),
    _ => null,
  };
  if (numeric == null) {
    return null;
  }
  final normalized = numeric > 1 && numeric <= 100 ? numeric / 100 : numeric;
  if (normalized < 0) {
    return 0;
  }
  if (normalized > 1) {
    return 1;
  }
  return normalized;
}

OnyxToolTarget? _toolTargetFromValue(Object? value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return switch (normalized) {
    'dispatchboard' ||
    'dispatch_board' ||
    'dispatch' ||
    'dispatches' ||
    'alarms' => OnyxToolTarget.dispatchBoard,
    'tacticaltrack' ||
    'tactical_track' ||
    'track' ||
    'telemetry' => OnyxToolTarget.tacticalTrack,
    'ai queue' ||
    'ai_queue' ||
    'ai-queue' ||
    'aiqueue' ||
    'cctvreview' ||
    'cctv_review' ||
    'cctv' ||
    'camera' ||
    'video' => OnyxToolTarget.cctvReview,
    'clientcomms' ||
    'client_comms' ||
    'client' ||
    'comms' => OnyxToolTarget.clientComms,
    'reportsworkspace' ||
    'reports_workspace' ||
    'reports' ||
    'reporting' ||
    'summary' => OnyxToolTarget.reportsWorkspace,
    _ => null,
  };
}

String _buildNarrative({
  required String rawText,
  required String summary,
  required String why,
  required List<String> missingInfo,
  required String narrative,
}) {
  if (narrative.trim().isNotEmpty) {
    return narrative.trim();
  }
  final parts = <String>[];
  if (summary.trim().isNotEmpty) {
    parts.add(summary.trim());
  }
  if (why.trim().isNotEmpty) {
    parts.add(why.trim());
  }
  if (missingInfo.isNotEmpty) {
    parts.add('Still confirm ${missingInfo.join(', ')}.');
  }
  if (parts.isEmpty) {
    return rawText.trim();
  }
  return parts.join(' ').trim();
}
