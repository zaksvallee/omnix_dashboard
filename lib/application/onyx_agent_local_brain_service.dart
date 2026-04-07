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
              'options': {'temperature': 0.2},
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
    return 'You are the local offline ONYX controller brain.\n'
        'Origin route: $route.\n'
        'Scope: client=$clientId site=$siteId incident=$incident.\n'
        'Intent: ${intent.name}.\n'
        'Rules:\n'
        '1) Be concise and operationally useful.\n'
        '2) Do not invent dispatches, ETAs, arrivals, or completed actions.\n'
        '3) Keep all device changes approval-gated.\n'
        '4) Never ask for or repeat secrets or credentials.\n'
        '5) Preferred output is compact JSON with keys summary, recommended_target, confidence, why, missing_info, primary_pressure, context_highlights, operator_focus_note, follow_up_label, follow_up_prompt, follow_up_status, text.\n'
        '6) Use recommended_target only as one of dispatchBoard, tacticalTrack, cctvReview, clientComms, reportsWorkspace.\n'
        '7) If JSON is not possible, return plain text.\n'
        '8) Keep the answer to two short paragraphs max.\n'
        '9) If an outstanding thread follow-up is marked unresolved or overdue, keep that checkpoint warm unless a stronger human-safety signal outranks it.\n'
        '10) Use follow_up_status only as one of pending, unresolved, overdue, cleared.\n'
        '11) If operator focus is preserved on the current thread, respect that manual context and explain any urgent review elsewhere without changing the desk recommendation unless safety clearly requires it.\n'
        '12) If operational context includes a primary pressure, echo it in primary_pressure using one of planner maintenance, overdue follow-up, unresolved follow-up, operator focus hold, or active signal watch.\n'
        '13) If operational context includes a planner maintenance priority, echo that pressure as a short first context_highlights item when it materially affects the next step.';
  }
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
