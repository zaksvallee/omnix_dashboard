import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'onyx_agent_cloud_boost_service.dart';

abstract class OnyxAgentLocalBrainService {
  bool get isConfigured;

  Future<OnyxAgentCloudBoostResponse?> synthesize({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  });
}

class UnconfiguredOnyxAgentLocalBrainService
    implements OnyxAgentLocalBrainService {
  const UnconfiguredOnyxAgentLocalBrainService();

  @override
  bool get isConfigured => false;

  @override
  Future<OnyxAgentCloudBoostResponse?> synthesize({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    return null;
  }
}

class OllamaOnyxAgentLocalBrainService implements OnyxAgentLocalBrainService {
  final http.Client client;
  final String model;
  final Uri endpoint;
  final Duration requestTimeout;

  OllamaOnyxAgentLocalBrainService({
    required this.client,
    required this.model,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 25),
  }) : endpoint = _resolveChatEndpoint(
         endpoint ?? Uri.parse('http://127.0.0.1:11434'),
       );

  @override
  bool get isConfigured => model.trim().isNotEmpty;

  @override
  Future<OnyxAgentCloudBoostResponse?> synthesize({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    final cleanedPrompt = prompt.trim();
    final providerLabel = 'local:ollama:${model.trim()}';
    if (!isConfigured || cleanedPrompt.isEmpty) {
      return null;
    }
    try {
      final response = await client
          .post(
            endpoint,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': model.trim(),
              'stream': false,
              'messages': [
                {'role': 'system', 'content': _systemPrompt(scope, intent)},
                if (scope.hasPendingFollowUp)
                  {
                    'role': 'system',
                    'content': onyxAgentPendingFollowUpContextForScope(scope),
                  },
                if (scope.hasOperatorFocusContext)
                  {
                    'role': 'system',
                    'content': onyxAgentOperatorFocusContextForScope(scope),
                  },
                if (contextSummary.trim().isNotEmpty)
                  {
                    'role': 'system',
                    'content': 'Operational context: ${contextSummary.trim()}',
                  },
                {'role': 'user', 'content': cleanedPrompt},
              ],
              'options': {'temperature': 0.2, 'num_predict': 280},
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return onyxAgentCloudBoostErrorResponse(
          providerLabel: providerLabel,
          errorSummary: 'Local brain request failed',
          errorDetail: 'Provider returned HTTP ${response.statusCode}.',
        );
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (error) {
        developer.log(
          'Local brain response JSON was invalid.',
          name: 'OnyxAgentLocalBrainService',
          error: error,
        );
        return onyxAgentCloudBoostErrorResponse(
          providerLabel: providerLabel,
          errorSummary: 'Local brain response was invalid',
          errorDetail:
              'Provider returned a response that could not be parsed as JSON.',
        );
      }
      final text = _extractLocalText(decoded);
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
        'Local brain synthesis failed.',
        name: 'OnyxAgentLocalBrainService',
        error: error,
        stackTrace: stackTrace,
      );
      return onyxAgentCloudBoostErrorResponse(
        providerLabel: providerLabel,
        errorSummary: 'Local brain request failed',
        errorDetail: '${error.runtimeType}: $error',
      );
    }
  }

  String _systemPrompt(OnyxAgentCloudScope scope, OnyxAgentCloudIntent intent) {
    final clientId = scope.clientId.trim().isEmpty ? 'global' : scope.clientId;
    final siteId = scope.siteId.trim().isEmpty ? 'all-sites' : scope.siteId;
    final incident = scope.incidentReference.trim().isEmpty
        ? 'none'
        : scope.incidentReference;
    final route = scope.sourceRouteLabel.trim().isEmpty
        ? 'Command'
        : scope.sourceRouteLabel;
    return 'You are ONYX Intelligence, an AI assistant embedded in a private security and intelligence operations platform. '
        'You assist operators, guards, and analysts with operational decisions, threat assessment, incident logging, and client management. '
        'Be direct, precise, and professional. Never fabricate data. If uncertain, say so.\n'
        'Route: $route | Scope: client=$clientId site=$siteId incident=$incident | Intent: ${intent.name} (${_intentGloss(intent)}).\n'
        'OUTPUT RULES (strict):\n'
        '- Return only a single JSON object with these exact keys: summary, recommended_target, confidence, why, missing_info, primary_pressure, context_highlights, operator_focus_note, follow_up_label, follow_up_prompt, follow_up_status, text.\n'
        '- recommended_target must be exactly one of: dispatchBoard, tacticalTrack, cctvReview, clientComms, reportsWorkspace.\n'
        '- follow_up_status must be exactly one of: pending, unresolved, overdue, cleared.\n'
        '- confidence is a float from 0.0 to 1.0.\n'
        '- context_highlights is a string array ordered by operational urgency.\n'
        '- If JSON is not achievable, return one plain-text sentence only with no markdown.\n'
        'OPERATIONAL RULES:\n'
        '1) Be concise and operationally useful. No narrative padding.\n'
        '2) Do not invent dispatches, ETAs, arrivals, or completed actions.\n'
        '3) All device changes stay approval-gated.\n'
        '4) Never ask for, echo, or repeat secrets or credentials.\n'
        '5) If an outstanding follow-up is unresolved or overdue, keep it warm unless a human-safety signal outranks it.\n'
        '6) If operator focus is preserved, respect it and avoid moving the desk recommendation unless safety clearly requires it.\n'
        '7) Echo primary_pressure from context when present using one of planner maintenance, overdue follow-up, unresolved follow-up, operator focus hold, or active signal watch.\n'
        '8) If a planner maintenance priority is in context, surface it as the first context_highlights item when it materially affects the next step.';
  }
}

String _intentGloss(OnyxAgentCloudIntent intent) {
  return switch (intent) {
    OnyxAgentCloudIntent.camera => 'CCTV / DVR device review',
    OnyxAgentCloudIntent.telemetry => 'sensor and alarm signal review',
    OnyxAgentCloudIntent.patrol => 'guard route and check-in tracking',
    OnyxAgentCloudIntent.client => 'client-facing communications',
    OnyxAgentCloudIntent.report => 'incident reporting and documentation',
    OnyxAgentCloudIntent.correlation => 'cross-site signal correlation',
    OnyxAgentCloudIntent.dispatch => 'guard or response unit deployment',
    OnyxAgentCloudIntent.admin => 'system and account administration',
    OnyxAgentCloudIntent.general => 'general operator query',
  };
}

Uri _resolveChatEndpoint(Uri endpoint) {
  final normalizedPath = endpoint.path.trim();
  if (normalizedPath.endsWith('/api/chat')) {
    return endpoint;
  }
  if (normalizedPath.isEmpty || normalizedPath == '/') {
    return endpoint.replace(path: '/api/chat');
  }
  if (normalizedPath.endsWith('/')) {
    return endpoint.replace(path: '${normalizedPath}api/chat');
  }
  return endpoint.replace(path: '$normalizedPath/api/chat');
}

String? _extractLocalText(Object? decoded) {
  if (decoded is! Map) {
    return null;
  }
  final map = decoded.cast<Object?, Object?>();
  final message = map['message'];
  if (message is Map) {
    final content = (message['content'] ?? '').toString().trim();
    if (content.isNotEmpty) {
      return content;
    }
  }
  final response = (map['response'] ?? '').toString().trim();
  if (response.isNotEmpty) {
    return response;
  }
  return null;
}
