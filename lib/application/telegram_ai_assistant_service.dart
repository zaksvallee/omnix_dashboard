import 'dart:convert';

import 'package:http/http.dart' as http;

enum TelegramAiAudience { admin, client }

enum TelegramAiDeliveryMode { telegramLive, approvalDraft, smsFallback }

class _TelegramAiScopeProfile {
  final String clientId;
  final String siteId;
  final String clientLabel;
  final String siteLabel;
  final String siteReference;

  const _TelegramAiScopeProfile({
    required this.clientId,
    required this.siteId,
    required this.clientLabel,
    required this.siteLabel,
    required this.siteReference,
  });
}

class TelegramAiDraftReply {
  final String text;
  final bool usedFallback;
  final String providerLabel;
  final bool usedLearnedApprovalStyle;

  const TelegramAiDraftReply({
    required this.text,
    this.usedFallback = false,
    this.providerLabel = 'fallback',
    this.usedLearnedApprovalStyle = false,
  });
}

abstract class TelegramAiAssistantService {
  bool get isConfigured;

  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    List<String> clientProfileSignals = const <String>[],
    List<String> preferredReplyExamples = const <String>[],
    List<String> learnedReplyExamples = const <String>[],
    List<String> recentConversationTurns = const <String>[],
  });
}

class UnconfiguredTelegramAiAssistantService
    implements TelegramAiAssistantService {
  const UnconfiguredTelegramAiAssistantService();

  @override
  bool get isConfigured => false;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    List<String> clientProfileSignals = const <String>[],
    List<String> preferredReplyExamples = const <String>[],
    List<String> learnedReplyExamples = const <String>[],
    List<String> recentConversationTurns = const <String>[],
  }) async {
    final scope = _scopeProfileFor(clientId: clientId, siteId: siteId);
    return TelegramAiDraftReply(
      text: _fallbackReply(
        audience: audience,
        messageText: messageText,
        scope: scope,
        deliveryMode: deliveryMode,
        clientProfileSignals: clientProfileSignals,
        preferredReplyExamples: preferredReplyExamples,
        recentConversationTurns: recentConversationTurns,
      ),
      usedFallback: true,
      providerLabel: 'fallback',
      usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
    );
  }
}

class OpenAiTelegramAiAssistantService implements TelegramAiAssistantService {
  final http.Client client;
  final String apiKey;
  final String model;
  final Uri endpoint;
  final Duration requestTimeout;

  OpenAiTelegramAiAssistantService({
    required this.client,
    required this.apiKey,
    required this.model,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 15),
  }) : endpoint = endpoint ?? Uri.parse('https://api.openai.com/v1/responses');

  @override
  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    List<String> clientProfileSignals = const <String>[],
    List<String> preferredReplyExamples = const <String>[],
    List<String> learnedReplyExamples = const <String>[],
    List<String> recentConversationTurns = const <String>[],
  }) async {
    final cleaned = messageText.trim();
    final scope = _scopeProfileFor(clientId: clientId, siteId: siteId);
    if (cleaned.isEmpty) {
      return TelegramAiDraftReply(
        text: _emptyPromptReply(audience: audience, scope: scope),
        usedFallback: true,
        usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
      );
    }
    if (!isConfigured) {
      return TelegramAiDraftReply(
        text: _fallbackReply(
          audience: audience,
          messageText: cleaned,
          scope: scope,
          deliveryMode: deliveryMode,
          clientProfileSignals: clientProfileSignals,
          recentConversationTurns: recentConversationTurns,
        ),
        usedFallback: true,
        usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
      );
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
              'max_output_tokens': 220,
              'input': [
                {
                  'role': 'system',
                  'content': [
                    {
                      'type': 'input_text',
                      'text': _systemPrompt(
                        audience: audience,
                        scope: scope,
                        messageText: cleaned,
                        deliveryMode: deliveryMode,
                        clientProfileSignals: clientProfileSignals,
                        preferredReplyExamples: preferredReplyExamples,
                        recentConversationTurns: recentConversationTurns,
                      ),
                    },
                  ],
                },
                {
                  'role': 'user',
                  'content': [
                    {'type': 'input_text', 'text': cleaned},
                  ],
                },
              ],
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return TelegramAiDraftReply(
          text: _fallbackReply(
            audience: audience,
            messageText: cleaned,
            scope: scope,
            deliveryMode: deliveryMode,
            clientProfileSignals: clientProfileSignals,
            preferredReplyExamples: preferredReplyExamples,
            recentConversationTurns: recentConversationTurns,
          ),
          usedFallback: true,
          usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
        );
      }
      final decoded = jsonDecode(response.body);
      final parsed = _extractText(decoded);
      if (parsed == null || parsed.trim().isEmpty) {
        return TelegramAiDraftReply(
          text: _fallbackReply(
            audience: audience,
            messageText: cleaned,
            scope: scope,
            deliveryMode: deliveryMode,
            clientProfileSignals: clientProfileSignals,
            preferredReplyExamples: preferredReplyExamples,
            recentConversationTurns: recentConversationTurns,
          ),
          usedFallback: true,
          usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
        );
      }
      final polished = _polishReply(
        audience: audience,
        text: parsed,
        messageText: cleaned,
        scope: scope,
        deliveryMode: deliveryMode,
        clientProfileSignals: clientProfileSignals,
        preferredReplyExamples: preferredReplyExamples,
        recentConversationTurns: recentConversationTurns,
      );
      if (polished.trim().isEmpty) {
        return TelegramAiDraftReply(
          text: _fallbackReply(
            audience: audience,
            messageText: cleaned,
            scope: scope,
            deliveryMode: deliveryMode,
            clientProfileSignals: clientProfileSignals,
            preferredReplyExamples: preferredReplyExamples,
            recentConversationTurns: recentConversationTurns,
          ),
          usedFallback: true,
          usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
        );
      }
      return TelegramAiDraftReply(
        text: polished,
        providerLabel: 'openai:${model.trim()}',
        usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
      );
    } catch (_) {
      return TelegramAiDraftReply(
        text: _fallbackReply(
          audience: audience,
          messageText: cleaned,
          scope: scope,
          deliveryMode: deliveryMode,
          clientProfileSignals: clientProfileSignals,
          preferredReplyExamples: preferredReplyExamples,
          recentConversationTurns: recentConversationTurns,
        ),
        usedFallback: true,
        usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
      );
    }
  }

  String _systemPrompt({
    required TelegramAiAudience audience,
    required _TelegramAiScopeProfile scope,
    required String messageText,
    required TelegramAiDeliveryMode deliveryMode,
    List<String> clientProfileSignals = const <String>[],
    List<String> preferredReplyExamples = const <String>[],
    List<String> recentConversationTurns = const <String>[],
  }) {
    final normalizedMessage = messageText.trim().toLowerCase();
    final recentContext = _recentConversationContextSnippet(
      recentConversationTurns,
    );
    final laneStage = _resolveClientLaneStage(
      normalizedMessage: normalizedMessage,
      recentConversationTurns: recentConversationTurns,
    );
    final tonePack = _clientTonePackFor(scope);
    final intent = _resolveClientReplyIntent(
      normalizedMessage,
      recentConversationTurns,
    );
    final escalatedLane = _isEscalatedLaneContext(
      normalizedMessage: normalizedMessage,
      recentConversationTurns: recentConversationTurns,
    );
    final pressuredLane = _isPressuredLaneContext(
      normalizedMessage: normalizedMessage,
      recentConversationTurns: recentConversationTurns,
    );
    final preferredExamplesSnippet = _preferredReplyExamplesSnippet(
      preferredReplyExamples,
    );
    switch (audience) {
      case TelegramAiAudience.admin:
        return 'You are ONYX operations admin assistant.\n'
            'Target scope: ${scope.clientId}/${scope.siteId}.\n'
            'Client label: ${scope.clientLabel}.\n'
            'Site label: ${scope.siteLabel}.\n'
            'Rules:\n'
            '1) Sound calm, direct, and operationally sharp.\n'
            '2) Prefer short executive answers with concrete next actions.\n'
            '3) Do not claim actions, dispatches, ETAs, or outcomes unless the user message explicitly confirms them.\n'
            '4) If context is missing, ask for one clarifying detail only.\n'
            '5) Plain text only. No markdown tables, bullets, or internal secrets.\n'
            'Recent lane context:\n'
            '$recentContext';
      case TelegramAiAudience.client:
        return 'You are ONYX client communications assistant for ${scope.siteReference}.\n'
            'Internal scope: ${scope.clientId}/${scope.siteId}.\n'
            'Client label: ${scope.clientLabel}.\n'
            'Site label: ${scope.siteLabel}.\n'
            'Voice and style:\n'
            '1) Sound like a calm, capable control-room operator, not a bot.\n'
            '2) Reassure first, then explain the next confirmed step.\n'
            '3) Keep most replies to 2 short sentences; use a third only if it truly helps.\n'
            '4) Do not mention internal IDs, scope strings, system tokens, pipelines, or model limitations.\n'
            '5) Never say "ONYX received your message", "command is reviewing", "verified update shortly", or similar canned system language.\n'
            '6) Never invent ETAs, dispatches, calls, or completed actions.\n'
            '7) If the client sounds worried, answer with calm reassurance. If details are missing, ask one simple follow-up.\n'
            '8) Avoid repeating the same reassurance line or closing sentence if recent lane context already used it.\n'
            '9) Plain text only.\n'
            '${escalatedLane ? '10) Recent lane context shows this thread is already escalated/high-priority. Keep the tone calm but tighter, more urgent, and centered on the next confirmed step.\n' : ''}'
            '${pressuredLane ? '11) Recent lane context shows repeated anxious follow-ups. Keep replies extra steady, brief, and avoid adding filler.\n' : ''}'
            '${_laneStagePromptNote(laneStage)}'
            '${_deliveryModePromptNote(deliveryMode)}'
            '${_clientTonePackPromptNote(tonePack)}'
            '${_clientProfilePromptNote(clientProfileSignals)}'
            '${_messageTypePromptNote(intent: intent, laneStage: laneStage, tonePack: tonePack)}'
            '${preferredExamplesSnippet == null ? '' : '14) Follow the wording pattern of the approved examples below when it fits the situation, especially for the closing line.\nPreferred approved reply examples:\n$preferredExamplesSnippet\n'}'
            'Recent lane context:\n'
            '$recentContext';
    }
  }
}

String _fallbackReply({
  required TelegramAiAudience audience,
  required String messageText,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  List<String> clientProfileSignals = const <String>[],
  List<String> preferredReplyExamples = const <String>[],
  List<String> recentConversationTurns = const <String>[],
}) {
  final normalized = messageText.trim().toLowerCase();
  final tonePack = _clientTonePackFor(scope);
  final clientProfile = _clientProfileFromSignals(clientProfileSignals);
  final laneStage = _resolveClientLaneStage(
    normalizedMessage: normalized,
    recentConversationTurns: recentConversationTurns,
  );
  final preferredReplyStyle = _preferredReplyStyleFromExamples(
    preferredReplyExamples,
  );
  final escalatedLane = _isEscalatedLaneContext(
    normalizedMessage: normalized,
    recentConversationTurns: recentConversationTurns,
  );
  final pressuredLane = _isPressuredLaneContext(
    normalizedMessage: normalized,
    recentConversationTurns: recentConversationTurns,
  );
  final intent = _resolveClientReplyIntent(
    normalized,
    recentConversationTurns,
  );
  final closing = _clientFollowUpClosing(
    recentConversationTurns,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );
  if (audience == TelegramAiAudience.admin) {
    return 'ONYX admin assistant: quick prompts work best.\n'
        'Try "brief", "status full", "critical risks", or "what should I do next?".';
  }
  if (deliveryMode == TelegramAiDeliveryMode.smsFallback) {
    return _smsFallbackReply(
      normalizedMessage: normalized,
      scope: scope,
      laneStage: laneStage,
      intent: intent,
      recentConversationTurns: recentConversationTurns,
      preferredReplyStyle: preferredReplyStyle,
      clientProfile: clientProfile,
      escalatedLane: escalatedLane,
      pressuredLane: pressuredLane,
    );
  }
  if (laneStage == _ClientLaneStage.closure) {
    if (_containsAny(
      normalized,
      const ['thank you', 'thanks', 'appreciate it'],
    )) {
      return 'You are welcome. The latest confirmed position is that ${scope.siteReference} is secure. If anything changes, message here immediately.';
    }
    if (intent == _ClientReplyIntent.access) {
      return _closureAccessReplyForTonePack(
        scope: scope,
        tonePack: tonePack,
      );
    }
    return _closureReplyForTonePack(scope: scope, tonePack: tonePack);
  }
  if (laneStage == _ClientLaneStage.responderOnSite) {
    if (intent == _ClientReplyIntent.access) {
      return '${_onSiteAccessLeadForTonePack(scope: scope, tonePack: tonePack)} ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.onsite, deliveryMode: deliveryMode, escalated: escalatedLane, compressed: pressuredLane)}';
    }
    if (intent == _ClientReplyIntent.visual) {
      return '${_onSiteVisualLeadForTonePack(scope: scope, tonePack: tonePack)} ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.visual, deliveryMode: deliveryMode, escalated: escalatedLane, compressed: pressuredLane)}';
    }
    if (intent == _ClientReplyIntent.worried) {
      return '${_onSiteWorriedLeadForTonePack(scope: scope, tonePack: tonePack)} ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.onsite, deliveryMode: deliveryMode, escalated: escalatedLane, compressed: pressuredLane)}';
    }
    return '${_onSiteStatusLeadForTonePack(scope: scope, tonePack: tonePack)} ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.onsite, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: escalatedLane, compressed: pressuredLane)}';
  }
  if (intent == _ClientReplyIntent.worried) {
    if (escalatedLane) {
      return '${_escalatedLeadForTonePack(scope: scope, tonePack: tonePack)} $closing';
    }
    if (pressuredLane) {
      return '${_worriedLeadForTonePack(scope: scope, tonePack: tonePack, pressured: true)} $closing';
    }
    return '${_worriedLeadForTonePack(scope: scope, tonePack: tonePack, clientProfile: clientProfile)} $closing';
  }
  if (intent == _ClientReplyIntent.access) {
    if (escalatedLane) {
      return '${_escalatedAccessLeadForTonePack(scope: scope, tonePack: tonePack)} ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.step, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: true, compressed: pressuredLane)}';
    }
    return '${_accessLeadForTonePack(scope: scope, tonePack: tonePack, clientProfile: clientProfile)} ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.step, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, clientProfile: clientProfile, escalated: escalatedLane, compressed: pressuredLane)}';
  }
  if (intent == _ClientReplyIntent.eta) {
    if (escalatedLane) {
      return 'This is already escalated with control for ${scope.siteReference}. We are checking live movement now. ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.eta, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: true, compressed: pressuredLane)}';
    }
    return 'We are checking live movement for ${scope.siteReference} now. ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.eta, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: escalatedLane, compressed: pressuredLane)}';
  }
  if (intent == _ClientReplyIntent.movement) {
    if (escalatedLane) {
      return 'This is already escalated with control for ${scope.siteReference}. We are checking responder status now. ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.movement, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: true, compressed: pressuredLane)}';
    }
    return 'We are checking responder status for ${scope.siteReference} now. ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.movement, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: escalatedLane, compressed: pressuredLane)}';
  }
  if (intent == _ClientReplyIntent.visual) {
    if (escalatedLane) {
      return '${_escalatedVisualLeadForTonePack(scope: scope, tonePack: tonePack)} ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.visual, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: true, compressed: pressuredLane)}';
    }
    return '${_visualLeadForTonePack(scope: scope, tonePack: tonePack, clientProfile: clientProfile)} ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.visual, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, clientProfile: clientProfile, escalated: escalatedLane, compressed: pressuredLane)}';
  }
  if (intent == _ClientReplyIntent.status) {
    if (escalatedLane) {
      return '${_escalatedStatusLeadForTonePack(scope: scope, tonePack: tonePack)} $closing';
    }
    if (pressuredLane) {
      return '${_statusLeadForTonePack(scope: scope, tonePack: tonePack, clientProfile: clientProfile, pressured: true)} $closing';
    }
    return '${_statusLeadForTonePack(scope: scope, tonePack: tonePack, clientProfile: clientProfile)} $closing';
  }
  if (_containsAny(
    normalized,
    const ['safe', 'okay', 'ok', 'all right', 'alright'],
  )) {
    return 'We are treating this seriously and checking ${scope.siteReference} now. If anything urgent changes, we will alert you immediately.';
  }
  if (_containsAny(
    normalized,
    const ['thank you', 'thanks', 'appreciate it'],
  )) {
    if (deliveryMode == TelegramAiDeliveryMode.approvalDraft) {
      return 'You are welcome. We are still tracking ${scope.siteReference}, and I will keep this lane updated if anything changes.';
    }
    return _thanksReplyForTonePack(
      scope: scope,
      tonePack: tonePack,
      clientProfile: clientProfile,
    );
  }
  if (_containsAny(
    normalized,
    const ['who are you', 'are you ai', 'are you a bot', 'robot'],
  )) {
    return 'I am ONYX support for ${scope.siteReference}. I can help with updates, response status, and getting control involved quickly.';
  }
  if (escalatedLane) {
    return 'We have your message and this is already escalated with control for ${scope.siteReference}. $closing';
  }
  return 'We have your message and we are checking ${scope.siteReference} now. $closing';
}

String _emptyPromptReply({
  required TelegramAiAudience audience,
  required _TelegramAiScopeProfile scope,
}) {
  if (audience == TelegramAiAudience.admin) {
    return 'Tell me what you want checked and I will keep it concise.';
  }
  return 'I can help with updates, access approvals, or urgent escalation for ${scope.siteReference}. Tell me what you would like checked.';
}

String _polishReply({
  required TelegramAiAudience audience,
  required String text,
  required String messageText,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  List<String> clientProfileSignals = const <String>[],
  List<String> preferredReplyExamples = const <String>[],
  List<String> recentConversationTurns = const <String>[],
}) {
  final normalized = text
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (normalized.isEmpty) {
    return '';
  }
  if (audience == TelegramAiAudience.admin) {
    return normalized;
  }
  var cleaned = normalized;
  cleaned = cleaned.replaceAll(
    RegExp(r'\b(?:CLIENT|SITE|REGION)-[A-Z0-9-]+\b'),
    '',
  );
  cleaned = cleaned.replaceAll(RegExp(r'\(\s*/?\s*\)'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  if (_looksMechanicalClientReply(cleaned)) {
    return _fallbackReply(
      audience: audience,
      messageText: messageText,
      scope: scope,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      recentConversationTurns: recentConversationTurns,
    );
  }
  return _normalizeClientReplyDrift(
    text: cleaned,
    deliveryMode: deliveryMode,
    laneStage: _resolveClientLaneStage(
      normalizedMessage: messageText.trim().toLowerCase(),
      recentConversationTurns: recentConversationTurns,
    ),
    preferredReplyStyle: _preferredReplyStyleFromExamples(
      preferredReplyExamples,
    ),
  );
}

bool _looksMechanicalClientReply(String text) {
  final normalized = text.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  if (_containsAny(normalized, const [
    'received your message',
    'command is reviewing',
    'verified update shortly',
    'internal scope',
    'scope:',
    'ticket',
    'case id',
    'as an ai',
    'language model',
  ])) {
    return true;
  }
  return RegExp(r'\b(?:client|site|region)-[a-z0-9-]+\b').hasMatch(normalized);
}

_TelegramAiScopeProfile _scopeProfileFor({
  String? clientId,
  String? siteId,
}) {
  final normalizedClientId = _normalizeScopeId(clientId, fallback: 'CLIENT');
  final normalizedSiteId = _normalizeScopeId(siteId, fallback: 'SITE');
  final clientLabel = _humanizeScopeLabel(
    normalizedClientId,
    fallback: 'your account',
  );
  final siteLabel = _humanizeScopeLabel(
    normalizedSiteId,
    fallback: 'your site',
  );
  return _TelegramAiScopeProfile(
    clientId: normalizedClientId,
    siteId: normalizedSiteId,
    clientLabel: clientLabel,
    siteLabel: siteLabel,
    siteReference: siteLabel == 'your site' ? 'your site' : siteLabel,
  );
}

String _normalizeScopeId(String? value, {required String fallback}) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

String _humanizeScopeLabel(String raw, {required String fallback}) {
  final cleaned = raw
      .trim()
      .replaceFirst(RegExp(r'^(CLIENT|SITE|REGION)-'), '')
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) {
    return fallback;
  }
  final stopWords = <String>{'and', 'of', 'the'};
  return cleaned
      .split(' ')
      .where((token) => token.trim().isNotEmpty)
      .toList(growable: false)
      .asMap()
      .entries
      .map((entry) {
        final original = entry.value.trim();
        final lower = entry.value.toLowerCase();
        if (original.length <= 2 &&
            RegExp(r'^[A-Z0-9]+$').hasMatch(original)) {
          return original;
        }
        if (entry.key > 0 && stopWords.contains(lower)) {
          return lower;
        }
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

bool _containsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) {
      return true;
    }
  }
  return false;
}

enum _FollowUpMode { general, eta, step, movement, visual, onsite }

enum _ClientReplyIntent { general, worried, access, eta, movement, visual, status }

enum _ClientLaneStage { reassurance, escalated, responderOnSite, closure }

enum _PreferredReplyStyle { defaultStyle, shareStyle }

enum _ClientTonePack { standard, residential, enterprise }

enum _ClientProfile {
  standard,
  conciseUpdates,
  reassuranceForward,
  validationHeavy,
}

String _laneStagePromptNote(_ClientLaneStage stage) {
  switch (stage) {
    case _ClientLaneStage.reassurance:
      return '';
    case _ClientLaneStage.escalated:
      return '';
    case _ClientLaneStage.responderOnSite:
      return '12) Recent lane stage shows security is already on site. Use calm on-site control language and focus on the next confirmed step on site, not ETA.\n';
    case _ClientLaneStage.closure:
      return '12) Recent lane stage shows the situation is already contained/resolved. Use calm closure language, confirm the site is secure, and invite the client to message immediately if anything changes.\n';
  }
}

String _deliveryModePromptNote(TelegramAiDeliveryMode deliveryMode) {
  switch (deliveryMode) {
    case TelegramAiDeliveryMode.telegramLive:
      return '12) This reply is for a live Telegram conversation. Keep it conversational, calm, and direct.\n';
    case TelegramAiDeliveryMode.approvalDraft:
      return '12) This reply is being drafted for operator approval before sending. Keep it send-ready, polished, and slightly fuller when that helps clarity.\n';
    case TelegramAiDeliveryMode.smsFallback:
      return '12) This reply may be sent as SMS fallback. Keep it very short, plain, and clear when read out of context.\n';
  }
}

String _clientTonePackPromptNote(_ClientTonePack tonePack) {
  switch (tonePack) {
    case _ClientTonePack.standard:
      return '';
    case _ClientTonePack.residential:
      return '12) This scope reads like a residential/private-community lane. Sound protective, calm, and human, while staying precise.\n';
    case _ClientTonePack.enterprise:
      return '12) This scope reads like a corporate/enterprise site. Sound composed, formal, and operations-grade.\n';
  }
}

String _clientProfilePromptNote(List<String> clientProfileSignals) {
  switch (_clientProfileFromSignals(clientProfileSignals)) {
    case _ClientProfile.standard:
      return '';
    case _ClientProfile.conciseUpdates:
      return '13) Recent lane memory shows this client prefers short operational updates. Keep replies tighter than usual.\n';
    case _ClientProfile.reassuranceForward:
      return '13) Recent lane memory shows this client responds better to calm reassurance before the next step. Keep that shape.\n';
    case _ClientProfile.validationHeavy:
      return '13) Recent lane memory shows this client prefers high-detail validation, especially around camera/daylight checks. Include the exact kind of check being confirmed.\n';
  }
}

String _messageTypePromptNote({
  required _ClientReplyIntent intent,
  required _ClientLaneStage laneStage,
  required _ClientTonePack tonePack,
}) {
  if (laneStage == _ClientLaneStage.closure) {
    return '13) This reply is a closure/secure-state update. Confirm the site is secure and make the reopen path simple.\n';
  }
  if (laneStage == _ClientLaneStage.responderOnSite) {
    return '13) This reply is in the on-site stage. Focus on the latest position on site and the next confirmed on-site step.\n';
  }
  switch (intent) {
    case _ClientReplyIntent.access:
      return tonePack == _ClientTonePack.enterprise
          ? '13) This message is about access control. Use precise access-control language and operational next steps.\n'
          : '13) This message is about access. Keep the wording practical and easy to act on.\n';
    case _ClientReplyIntent.visual:
      return tonePack == _ClientTonePack.residential
          ? '13) This message is about camera/daylight validation. Use calm visual-check language that feels protective and clear.\n'
          : '13) This message is about camera/daylight validation. Keep the visual update precise and grounded.\n';
    default:
      return '';
  }
}

String _clientFollowUpClosing(
  List<String> recentConversationTurns, {
  _FollowUpMode mode = _FollowUpMode.general,
  TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
  _PreferredReplyStyle preferredReplyStyle = _PreferredReplyStyle.defaultStyle,
  _ClientProfile clientProfile = _ClientProfile.standard,
  bool escalated = false,
  bool compressed = false,
}) {
  if (deliveryMode == TelegramAiDeliveryMode.smsFallback) {
    switch (mode) {
      case _FollowUpMode.general:
        return escalated
            ? 'Control will update you on the next confirmed step.'
            : 'Control will send the next confirmed step.';
      case _FollowUpMode.eta:
        return 'Control will send the ETA when confirmed.';
      case _FollowUpMode.step:
        return 'Control will send the next confirmed step.';
      case _FollowUpMode.movement:
        return 'Control will send the next movement once confirmed.';
      case _FollowUpMode.visual:
        return 'Control will send the latest confirmed visual.';
      case _FollowUpMode.onsite:
        return 'Control will send the next confirmed on-site step.';
    }
  }
  final normalized = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final repeatedConfirmed = normalized.contains('next confirmed update');
  final repeatedKeepPosted = normalized.contains('keep you posted');
  final repeatedMoment = normalized.contains('the moment control confirms');
  final preferConcise = clientProfile == _ClientProfile.conciseUpdates;
  switch (mode) {
    case _FollowUpMode.onsite:
      if (preferConcise) {
        return 'I will share the next on-site step when confirmed.';
      }
      if (compressed) {
        return escalated
            ? 'I will update you here the moment the next on-site step is confirmed.'
            : 'I will update you here the moment control confirms the next on-site step.';
      }
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next confirmed on-site step the moment control has it.';
      }
      if (deliveryMode == TelegramAiDeliveryMode.approvalDraft) {
        return 'I will share the next confirmed on-site step the moment control has it.';
      }
      if (escalated) {
        return 'I will update you here the moment control confirms the next on-site step.';
      }
      if (repeatedConfirmed || repeatedKeepPosted || repeatedMoment) {
        return 'As soon as control confirms the next on-site step, I will update you here.';
      }
      return 'I will send the next confirmed on-site step as soon as control has it.';
    case _FollowUpMode.eta:
      if (preferConcise) {
        return 'I will share the ETA when confirmed.';
      }
      if (compressed) {
        return escalated
            ? 'I will update you here the moment the ETA is confirmed.'
            : 'I will update you here the moment control confirms the ETA.';
      }
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the ETA the moment control confirms it.';
      }
      if (deliveryMode == TelegramAiDeliveryMode.approvalDraft) {
        return 'I will share the ETA the moment control confirms it.';
      }
      if (escalated) {
        return 'I will update you here the moment control confirms the ETA.';
      }
      if (repeatedConfirmed || repeatedKeepPosted) {
        return 'The moment control confirms the ETA, I will update you here.';
      }
      return 'I will send the ETA as soon as control confirms it.';
    case _FollowUpMode.step:
      if (preferConcise) {
        return 'I will share the next step when confirmed.';
      }
      if (compressed) {
        return escalated
            ? 'I will update you here the moment the next step is confirmed.'
            : 'I will update you here the moment control confirms the next step.';
      }
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next confirmed step the moment control has it.';
      }
      if (deliveryMode == TelegramAiDeliveryMode.approvalDraft) {
        return 'I will share the next confirmed step the moment control has it.';
      }
      if (escalated) {
        return 'I will update you here the moment control confirms the next step.';
      }
      if (repeatedConfirmed || repeatedKeepPosted) {
        return 'As soon as control confirms the next step, I will update you here.';
      }
      return 'I will send the next confirmed step as soon as control has it.';
    case _FollowUpMode.movement:
      if (preferConcise) {
        return 'I will share the next movement when confirmed.';
      }
      if (compressed) {
        return escalated
            ? 'I will update you here the moment movement is confirmed.'
            : 'I will update you here the moment control confirms movement.';
      }
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next confirmed movement the moment control has it.';
      }
      if (deliveryMode == TelegramAiDeliveryMode.approvalDraft) {
        return 'I will share the next confirmed movement the moment control has it.';
      }
      if (escalated) {
        return 'I will update you here the moment control confirms the next movement.';
      }
      if (repeatedConfirmed || repeatedKeepPosted || repeatedMoment) {
        return 'As soon as control confirms the next movement, I will update you here.';
      }
      return 'I will share the next confirmed movement update as soon as control has it.';
    case _FollowUpMode.visual:
      if (clientProfile == _ClientProfile.validationHeavy) {
        return 'I will share the next confirmed visual check the moment control verifies it.';
      }
      if (preferConcise) {
        return 'I will share the next visual check when confirmed.';
      }
      if (compressed) {
        return escalated
            ? 'I will update you here the moment the latest visual is confirmed.'
            : 'I will update you here the moment control verifies the latest visual.';
      }
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next confirmed visual the moment control verifies it.';
      }
      if (deliveryMode == TelegramAiDeliveryMode.approvalDraft) {
        return 'I will share the next confirmed visual the moment control verifies it.';
      }
      if (escalated) {
        return 'I will update you here the moment control verifies the latest visual.';
      }
      if (repeatedConfirmed || repeatedKeepPosted || repeatedMoment) {
        return 'As soon as control verifies the latest visual, I will update you here.';
      }
      return 'I will send the next confirmed visual update as soon as control verifies it.';
    case _FollowUpMode.general:
      if (preferConcise) {
        return 'I will share the next step when confirmed.';
      }
      if (compressed) {
        return escalated
            ? 'I will update you here the moment the next step is confirmed.'
            : 'I will update you here the moment control confirms the next step.';
      }
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next confirmed step the moment control has it.';
      }
      if (deliveryMode == TelegramAiDeliveryMode.approvalDraft) {
        return 'I will keep this lane updated with the next confirmed step.';
      }
      if (escalated) {
        return 'I will update you here the moment control confirms the next step.';
      }
      if (repeatedConfirmed) {
        return 'I will keep this lane updated the moment control confirms the next step.';
      }
      if (repeatedKeepPosted) {
        return 'The moment control has the next confirmed detail, I will update you here.';
      }
      if (repeatedMoment) {
        return 'I will keep you posted with the next confirmed update.';
      }
      return 'I will send the next confirmed update as soon as control has it.';
  }
}

String _smsFallbackReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required _ClientLaneStage laneStage,
  required _ClientReplyIntent intent,
  required List<String> recentConversationTurns,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required bool escalatedLane,
  required bool pressuredLane,
}) {
  if (laneStage == _ClientLaneStage.closure) {
    return '${scope.siteReference} is secure. Message immediately if anything changes.';
  }
  if (laneStage == _ClientLaneStage.responderOnSite) {
    if (intent == _ClientReplyIntent.visual) {
      return 'Security is on site at ${scope.siteReference}. Control will send the latest confirmed visual.';
    }
    return 'Security is on site at ${scope.siteReference}. Control will send the next confirmed on-site step.';
  }
  if (intent == _ClientReplyIntent.worried) {
    if (escalatedLane) {
      return 'High-priority alert escalated for ${scope.siteReference}. Control is on it now. Control will update you on the next confirmed step.';
    }
    return 'We are treating ${scope.siteReference} as live. Control is checking now. Control will send the next confirmed step.';
  }
  if (intent == _ClientReplyIntent.access) {
    return escalatedLane
        ? 'Access issue escalated for ${scope.siteReference}. Control will send the next confirmed step.'
        : 'We are checking access for ${scope.siteReference}. Control will send the next confirmed step.';
  }
  if (intent == _ClientReplyIntent.eta) {
    return escalatedLane
        ? 'Movement is escalated for ${scope.siteReference}. Control will send the ETA when confirmed.'
        : 'We are checking movement for ${scope.siteReference}. Control will send the ETA when confirmed.';
  }
  if (intent == _ClientReplyIntent.visual) {
    return escalatedLane
        ? 'Visual check escalated for ${scope.siteReference}. Control will send the latest confirmed visual.'
        : clientProfile == _ClientProfile.validationHeavy
            ? 'We are checking the latest camera and daylight view for ${scope.siteReference}. Control will send the latest confirmed visual.'
            : 'We are checking the latest camera view for ${scope.siteReference}. Control will send the latest confirmed visual.';
  }
  if (_containsAny(
    normalizedMessage,
    const ['thank you', 'thanks', 'appreciate it'],
  )) {
    return 'You are welcome. Control will update you if anything changes.';
  }
  if (escalatedLane) {
    return 'This is escalated for ${scope.siteReference}. Control will update you on the next confirmed step.';
  }
  if (pressuredLane) {
    return 'We are on it at ${scope.siteReference}. Control will send the next confirmed step.';
  }
  return 'We are checking ${scope.siteReference}. Control will send the next confirmed step.';
}

_ClientTonePack _clientTonePackFor(_TelegramAiScopeProfile scope) {
  final joined =
      '${scope.clientId} ${scope.siteId} ${scope.clientLabel} ${scope.siteLabel}'
          .toLowerCase();
  if (_containsAny(
    joined,
    const [
      'residence',
      'residential',
      'estate',
      'villa',
      'home',
      'community',
      'vallee',
    ],
  )) {
    return _ClientTonePack.residential;
  }
  if (_containsAny(
    joined,
    const [
      'tower',
      'campus',
      'office',
      'industrial',
      'business',
      'corporate',
      'enterprise',
      'park',
      'centre',
      'center',
    ],
  )) {
    return _ClientTonePack.enterprise;
  }
  return _ClientTonePack.standard;
}

String _worriedLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
  _ClientProfile clientProfile = _ClientProfile.standard,
  bool pressured = false,
}) {
  if (clientProfile == _ClientProfile.reassuranceForward) {
    return pressured
        ? 'You are not alone. We are treating this as live at ${scope.siteReference} now and staying close on this lane.'
        : 'You are not alone. We are treating this as live at ${scope.siteReference} and checking it now.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return pressured
          ? 'You are not alone. We are treating this as live at ${scope.siteReference} now and keeping this lane steady for you.'
          : 'You are not alone. We are treating this as live at ${scope.siteReference} and checking it now.';
    case _ClientTonePack.enterprise:
      return pressured
          ? 'We are treating this as an active operations matter at ${scope.siteReference} now.'
          : 'We are treating this as an active operations matter at ${scope.siteReference} and checking it now.';
    case _ClientTonePack.standard:
      return pressured
          ? 'You are not alone. We are treating this as live at ${scope.siteReference} now.'
          : 'You are not alone. We are treating this as live at ${scope.siteReference} and checking it now.';
  }
}

String _statusLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
  _ClientProfile clientProfile = _ClientProfile.standard,
  bool pressured = false,
}) {
  if (clientProfile == _ClientProfile.conciseUpdates) {
    return pressured
        ? 'We are on it at ${scope.siteReference} now.'
        : 'We are checking ${scope.siteReference} now.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return pressured
          ? 'We are on it at ${scope.siteReference} now.'
          : 'We are on it at ${scope.siteReference} and control is checking the latest position now.';
    case _ClientTonePack.enterprise:
      return pressured
          ? 'We are actively checking the latest position for ${scope.siteReference} now.'
          : 'We are actively checking the latest position for ${scope.siteReference} now.';
    case _ClientTonePack.standard:
      return pressured
          ? 'We are on it at ${scope.siteReference} now.'
          : 'We are on it at ${scope.siteReference} and control is checking the latest position now.';
  }
}

String _escalatedLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'This is already escalated with control for ${scope.siteReference}. We are actively on it now.';
    case _ClientTonePack.enterprise:
      return 'This is already escalated with control for ${scope.siteReference}. We are actively coordinating the next step now.';
    case _ClientTonePack.standard:
      return 'This is already escalated with control for ${scope.siteReference}. We are actively on it now.';
  }
}

String _escalatedStatusLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'This is already escalated with control for ${scope.siteReference}. We are actively checking the latest position now.';
    case _ClientTonePack.enterprise:
      return 'This is already escalated with control for ${scope.siteReference}. We are actively checking the latest operational position now.';
    case _ClientTonePack.standard:
      return 'This is already escalated with control for ${scope.siteReference}. We are actively checking the latest position now.';
  }
}

String _thanksReplyForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
  _ClientProfile clientProfile = _ClientProfile.standard,
}) {
  if (clientProfile == _ClientProfile.reassuranceForward) {
    return 'You are welcome. We are still tracking ${scope.siteReference} and will keep this lane close if anything changes.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'You are welcome. We are still tracking ${scope.siteReference} and will keep this lane updated if anything changes.';
    case _ClientTonePack.enterprise:
      return 'You are welcome. We are still tracking ${scope.siteReference} and will continue to update this lane if anything changes.';
    case _ClientTonePack.standard:
      return 'You are welcome. We are still tracking ${scope.siteReference} and will update you if anything changes.';
  }
}

_ClientProfile _clientProfileFromSignals(List<String> clientProfileSignals) {
  final joined = clientProfileSignals
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.contains('validation-heavy')) {
    return _ClientProfile.validationHeavy;
  }
  if (joined.contains('reassurance-forward')) {
    return _ClientProfile.reassuranceForward;
  }
  if (joined.contains('concise-updates')) {
    return _ClientProfile.conciseUpdates;
  }
  return _ClientProfile.standard;
}

String _accessLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
  _ClientProfile clientProfile = _ClientProfile.standard,
}) {
  if (clientProfile == _ClientProfile.conciseUpdates) {
    return tonePack == _ClientTonePack.enterprise
        ? 'We are checking access control for ${scope.siteReference} now.'
        : 'We are checking access for ${scope.siteReference} now.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'We are checking access status for ${scope.siteReference} now.';
    case _ClientTonePack.enterprise:
      return 'We are checking access-control status for ${scope.siteReference} now.';
    case _ClientTonePack.standard:
      return 'We are checking access status for ${scope.siteReference} now.';
  }
}

String _escalatedAccessLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'This is already escalated with control for ${scope.siteReference}. We are checking access status now.';
    case _ClientTonePack.enterprise:
      return 'This is already escalated with control for ${scope.siteReference}. We are checking access-control status now.';
    case _ClientTonePack.standard:
      return 'This is already escalated with control for ${scope.siteReference}. We are checking access status now.';
  }
}

String _visualLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
  _ClientProfile clientProfile = _ClientProfile.standard,
}) {
  if (clientProfile == _ClientProfile.validationHeavy) {
    return tonePack == _ClientTonePack.residential
        ? 'We are checking the latest camera and daylight view around ${scope.siteReference} now.'
        : 'We are checking the latest camera and daylight view for ${scope.siteReference} now.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'We are checking the latest camera view around ${scope.siteReference} now.';
    case _ClientTonePack.enterprise:
      return 'We are checking the latest camera view for ${scope.siteReference} now.';
    case _ClientTonePack.standard:
      return 'We are checking the latest camera view for ${scope.siteReference} now.';
  }
}

String _escalatedVisualLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'This is already escalated with control for ${scope.siteReference}. We are checking the latest camera view around the site now.';
    case _ClientTonePack.enterprise:
      return 'This is already escalated with control for ${scope.siteReference}. We are checking the latest camera view now.';
    case _ClientTonePack.standard:
      return 'This is already escalated with control for ${scope.siteReference}. We are checking the latest camera view now.';
  }
}

String _onSiteAccessLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'Security is already on site at ${scope.siteReference}. We are checking access status there now.';
    case _ClientTonePack.enterprise:
      return 'Security is already on site at ${scope.siteReference}. We are checking access-control status now.';
    case _ClientTonePack.standard:
      return 'Security is already on site at ${scope.siteReference}. We are checking access status now.';
  }
}

String _onSiteVisualLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'Security is already on site at ${scope.siteReference}. We are checking the latest camera and perimeter view now.';
    case _ClientTonePack.enterprise:
      return 'Security is already on site at ${scope.siteReference}. We are checking the latest camera and on-site view now.';
    case _ClientTonePack.standard:
      return 'Security is already on site at ${scope.siteReference}. We are checking the latest camera and on-site view now.';
  }
}

String _onSiteWorriedLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'Security is already on site at ${scope.siteReference}. We are actively checking the position there now.';
    case _ClientTonePack.enterprise:
      return 'Security is already on site at ${scope.siteReference}. We are actively checking the operational position there now.';
    case _ClientTonePack.standard:
      return 'Security is already on site at ${scope.siteReference}. We are actively checking the position there now.';
  }
}

String _onSiteStatusLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'Security is already on site at ${scope.siteReference}. We are checking the latest on-site position there now.';
    case _ClientTonePack.enterprise:
      return 'Security is already on site at ${scope.siteReference}. We are confirming the latest on-site position now.';
    case _ClientTonePack.standard:
      return 'Security is already on site at ${scope.siteReference}. We are checking the latest on-site position now.';
  }
}

String _closureReplyForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'The latest confirmed position is that ${scope.siteReference} is secure. If anything changes or feels off again, message here immediately and we will reopen this at once.';
    case _ClientTonePack.enterprise:
      return 'The latest confirmed position is that ${scope.siteReference} is secure. If anything changes again, message here immediately and we will reopen the incident at once.';
    case _ClientTonePack.standard:
      return 'The latest confirmed position is that ${scope.siteReference} is secure. If anything changes or feels off again, message here immediately and we will reopen this at once.';
  }
}

String _closureAccessReplyForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'The latest confirmed position is that ${scope.siteReference} is secure. If access is still affected, tell me what is blocked and we will reopen this now.';
    case _ClientTonePack.enterprise:
      return 'The latest confirmed position is that ${scope.siteReference} is secure. If access control is still affected, tell me what is blocked and we will reopen this now.';
    case _ClientTonePack.standard:
      return 'The latest confirmed position is that ${scope.siteReference} is secure. If access is still affected, tell me what is blocked and we will reopen this now.';
  }
}

String _normalizeClientReplyDrift({
  required String text,
  required TelegramAiDeliveryMode deliveryMode,
  required _ClientLaneStage laneStage,
  required _PreferredReplyStyle preferredReplyStyle,
}) {
  var normalized = text.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  final followUpMode = _followUpModeFromReplyText(
    normalized,
    laneStage: laneStage,
  );
  if (deliveryMode == TelegramAiDeliveryMode.smsFallback &&
      normalized.toLowerCase().contains('i will')) {
    final preferredClosing = _clientFollowUpClosing(
      const <String>[],
      mode: followUpMode,
      deliveryMode: deliveryMode,
    );
    return _replaceClosingSentence(normalized, preferredClosing);
  }
  if (preferredReplyStyle == _PreferredReplyStyle.shareStyle &&
      !_containsAny(
        normalized.toLowerCase(),
        const ['i will share', 'control will send'],
      ) &&
      _containsAny(
        normalized.toLowerCase(),
        const [
          'i will send',
          'i will update you here',
          'keep this lane updated',
          'keep you posted',
        ],
      )) {
    final preferredClosing = _clientFollowUpClosing(
      const <String>[],
      mode: followUpMode,
      deliveryMode: TelegramAiDeliveryMode.approvalDraft,
      preferredReplyStyle: preferredReplyStyle,
    );
    normalized = _replaceClosingSentence(normalized, preferredClosing);
  }
  return normalized;
}

_FollowUpMode _followUpModeFromReplyText(
  String text, {
  required _ClientLaneStage laneStage,
}) {
  final normalized = text.trim().toLowerCase();
  if (laneStage == _ClientLaneStage.responderOnSite &&
      _containsAny(normalized, const ['on site', 'on-site'])) {
    return _FollowUpMode.onsite;
  }
  if (_containsAny(normalized, const ['eta', 'live movement', 'arrival'])) {
    return _FollowUpMode.eta;
  }
  if (_containsAny(normalized, const ['access status', 'gate', 'access'])) {
    return _FollowUpMode.step;
  }
  if (_containsAny(
    normalized,
    const ['responder status', 'movement', 'armed response', 'officer'],
  )) {
    return _FollowUpMode.movement;
  }
  if (_containsAny(
    normalized,
    const ['camera', 'visual', 'cctv', 'footage', 'latest view'],
  )) {
    return _FollowUpMode.visual;
  }
  if (laneStage == _ClientLaneStage.responderOnSite) {
    return _FollowUpMode.onsite;
  }
  return _FollowUpMode.general;
}

String _replaceClosingSentence(String text, String replacement) {
  final trimmed = text.trim();
  final boundary = trimmed.lastIndexOf('. ');
  if (boundary >= 0) {
    return '${trimmed.substring(0, boundary + 2)}$replacement';
  }
  return replacement;
}

String? _preferredReplyExamplesSnippet(List<String> preferredReplyExamples) {
  final cleaned = preferredReplyExamples
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .take(3)
      .toList(growable: false);
  if (cleaned.isEmpty) {
    return null;
  }
  return cleaned.join('\n');
}

_PreferredReplyStyle _preferredReplyStyleFromExamples(
  List<String> preferredReplyExamples,
) {
  final joined = preferredReplyExamples
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.contains('i will share')) {
    return _PreferredReplyStyle.shareStyle;
  }
  return _PreferredReplyStyle.defaultStyle;
}

bool _isEscalatedLaneContext({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  if (_containsAny(
    normalizedMessage,
    const [
      'help me',
      'please help',
      'panic',
      'unsafe',
      'emergency',
      'intruder',
      'break in',
      'break-in',
      'attack',
      'gun',
      'weapon',
      'threat',
    ],
  )) {
    return true;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return _containsAny(
    joined,
    const [
      'escalated',
      'client escalated',
      'high-priority',
      'high priority',
      'alert received',
      'verification requested',
      'control room',
      'policy:high-risk',
    ],
  );
}

bool _isPressuredLaneContext({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  var pressureSignals = 0;
  if (_containsAny(
    normalizedMessage,
    const [
      'worried',
      'scared',
      'afraid',
      'panic',
      'unsafe',
      'help',
      'any update',
      'still waiting',
      'still no',
      'anything yet',
      'what now',
    ],
  )) {
    pressureSignals += 1;
  }
  for (final turn in recentConversationTurns.take(6)) {
    final normalizedTurn = turn.trim().toLowerCase();
    if (normalizedTurn.isEmpty) {
      continue;
    }
    if (_containsAny(
      normalizedTurn,
      const [
        'worried',
        'scared',
        'afraid',
        'panic',
        'unsafe',
        'please help',
        'help me',
        'any update',
        'still waiting',
        'still no',
        'anything yet',
        'what now',
        'update?',
        'yet?',
      ],
    )) {
      pressureSignals += 1;
    }
  }
  return pressureSignals >= 2;
}

_ClientLaneStage _resolveClientLaneStage({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (_containsAny(
    joined,
    const [
      'incident resolved',
      'site secured',
      'resolved',
      'all clear',
      'closed out',
      'closure',
    ],
  )) {
    return _ClientLaneStage.closure;
  }
  if (_containsAny(
    joined,
    const [
      'responder on site',
      'security response activated',
      'partner dispatch sent',
      'response activated',
      'on site',
      'on-site',
    ],
  )) {
    return _ClientLaneStage.responderOnSite;
  }
  if (_isEscalatedLaneContext(
    normalizedMessage: normalizedMessage,
    recentConversationTurns: recentConversationTurns,
  )) {
    return _ClientLaneStage.escalated;
  }
  return _ClientLaneStage.reassurance;
}

String _recentConversationContextSnippet(List<String> recentConversationTurns) {
  final trimmed = recentConversationTurns
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .take(6)
      .toList(growable: false);
  if (trimmed.isEmpty) {
    return 'none';
  }
  return trimmed.join('\n');
}

_ClientReplyIntent _resolveClientReplyIntent(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (_containsAny(
    normalizedMessage,
    const [
      'worried',
      'scared',
      'afraid',
      'panic',
      'panicking',
      'nervous',
      'unsafe',
      'help me',
      'please help',
    ],
  )) {
    return _ClientReplyIntent.worried;
  }
  if (_containsAny(
    normalizedMessage,
    const [
      'gate',
      'access',
      'cant get in',
      'can\'t get in',
      'cant get out',
      'can\'t get out',
      'stuck outside',
      'stuck inside',
    ],
  )) {
    return _ClientReplyIntent.access;
  }
  if (_containsAny(
    normalizedMessage,
    const ['eta', 'arrival', 'arrive', 'how far', 'how long'],
  )) {
    return _ClientReplyIntent.eta;
  }
  if (_containsAny(
    normalizedMessage,
    const [
      'guard',
      'officer',
      'response unit',
      'responder',
      'armed response',
      'police',
      'who is coming',
    ],
  )) {
    return _ClientReplyIntent.movement;
  }
  if (_containsAny(
    normalizedMessage,
    const [
      'camera',
      'cctv',
      'video',
      'footage',
      'see on camera',
      'what do you see',
      'daylight',
    ],
  )) {
    return _ClientReplyIntent.visual;
  }
  if (_containsAny(
    normalizedMessage,
    const ['status', 'update', 'progress', 'news', 'happening'],
  )) {
    return _ClientReplyIntent.status;
  }
  if (_looksLikeShortFollowUp(normalizedMessage)) {
    return _intentFromRecentConversation(recentConversationTurns);
  }
  return _ClientReplyIntent.general;
}

bool _looksLikeShortFollowUp(String normalizedMessage) {
  if (normalizedMessage.isEmpty) {
    return false;
  }
  if (normalizedMessage.split(RegExp(r'\s+')).length > 6) {
    return false;
  }
  return _containsAny(
    normalizedMessage,
    const [
      'still waiting',
      'anything yet',
      'any update',
      'and now',
      'what now',
      'still',
      'yet',
      'now?',
      'update?',
      'still no',
    ],
  );
}

_ClientReplyIntent _intentFromRecentConversation(
  List<String> recentConversationTurns,
) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return _ClientReplyIntent.status;
  }
  if (_containsAny(joined, const ['latest camera view', 'confirmed visual update'])) {
    return _ClientReplyIntent.visual;
  }
  if (_containsAny(joined, const ['live movement', 'eta'])) {
    return _ClientReplyIntent.eta;
  }
  if (_containsAny(joined, const ['access status', 'confirmed step'])) {
    return _ClientReplyIntent.access;
  }
  if (_containsAny(joined, const ['responder status', 'movement update'])) {
    return _ClientReplyIntent.movement;
  }
  if (_containsAny(joined, const ['treating this as live', 'you are not alone'])) {
    return _ClientReplyIntent.worried;
  }
  return _ClientReplyIntent.status;
}

String? _extractText(Object? decoded) {
  if (decoded is! Map) return null;
  final map = decoded.cast<Object?, Object?>();
  final outputText = map['output_text'];
  if (outputText is String && outputText.trim().isNotEmpty) {
    return outputText.trim();
  }
  final output = map['output'];
  if (output is List) {
    final chunks = <String>[];
    for (final item in output) {
      if (item is! Map) continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is! Map) continue;
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
