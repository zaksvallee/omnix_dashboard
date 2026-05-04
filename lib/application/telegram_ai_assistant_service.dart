import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'client_camera_health_fact_packet_service.dart';
import 'onyx_agent_cloud_boost_service.dart';
import 'onyx_agent_local_brain_service.dart';
import 'telegram_ai_text_utils.dart';
import 'telegram_client_prompt_signals.dart';

part 'telegram_ai_assistant_camera_health.dart';
part 'telegram_ai_assistant_clarifiers.dart';
part 'telegram_ai_assistant_site_view.dart';

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

class _TelegramAiClientPromptContext {
  final String clientName;
  final String siteName;
  final String watchStatus;
  final String cameraStatus;
  final String activeIncidents;
  final String lastActivity;
  final String guardOnSite;
  final String lastGuardCheckin;

  const _TelegramAiClientPromptContext({
    required this.clientName,
    required this.siteName,
    required this.watchStatus,
    required this.cameraStatus,
    required this.activeIncidents,
    required this.lastActivity,
    required this.guardOnSite,
    required this.lastGuardCheckin,
  });
}

class TelegramAiSiteAwarenessSummary {
  final DateTime observedAtUtc;
  final bool perimeterClear;
  final int humanCount;
  final int vehicleCount;
  final int animalCount;
  final int motionCount;
  final int activeAlertCount;
  final List<String> knownFaultChannels;

  const TelegramAiSiteAwarenessSummary({
    required this.observedAtUtc,
    required this.perimeterClear,
    required this.humanCount,
    required this.vehicleCount,
    required this.animalCount,
    required this.motionCount,
    required this.activeAlertCount,
    this.knownFaultChannels = const <String>[],
  });

  String get watchStatusPromptValue => perimeterClear
      ? 'active from fresh live site snapshot'
      : 'active from fresh live site snapshot with a perimeter alert';

  String get cameraStatusPromptValue {
    if (knownFaultChannels.isEmpty) {
      return 'active from fresh live site snapshot';
    }
    return 'active from fresh live site snapshot with ${_channelFaultPromptLabel()}';
  }

  String get activeIncidentsPromptValue {
    if (activeAlertCount > 0 || !perimeterClear) {
      return '$activeAlertCount active - live site snapshot shows ${perimeterClear ? 'alerts on site' : 'a perimeter alert'}';
    }
    return '0 active - live site snapshot shows perimeter clear';
  }

  String get lastActivityPromptValue =>
      '${observedAtUtc.toUtc().toIso8601String()} - live site snapshot: ${_perimeterPromptLabel()}, ${_countLabel(humanCount, 'person')}, ${_countLabel(vehicleCount, 'vehicle')}, ${_countLabel(animalCount, 'animal')}';

  String get contextSummary =>
      '${_perimeterPromptLabel()}, ${_countLabel(humanCount, 'person')}, ${_countLabel(vehicleCount, 'vehicle')}, ${_countLabel(animalCount, 'animal')}, ${_countLabel(activeAlertCount, 'active alert')}, ${knownFaultChannels.isEmpty ? 'all reporting channels healthy' : _channelFaultPromptLabel()}';

  String clientMonitoringSummary({
    required String siteReference,
    String? extraDetail,
    String? nextStepQuestion,
  }) {
    final normalizedSiteReference = siteReference.trim().isEmpty
        ? 'the site'
        : siteReference.trim();
    final onSiteLabel = _presenceSummaryLabel();
    final channelLine = knownFaultChannels.isEmpty
        ? 'Channel status: All reporting channels healthy'
        : 'Channel status: ${_channelFaultStatusLine()}';
    final parts = <String>[
      'Monitoring active at $normalizedSiteReference.',
      'Perimeter: ${perimeterClear ? 'Clear' : 'Alert active'}',
      'On site: $onSiteLabel',
      'Active alerts: ${activeAlertCount == 0 ? 'None' : _countLabel(activeAlertCount, 'active alert')}',
      'Last update: ${_relativeAgeLabel()}',
      channelLine,
      if (extraDetail != null && extraDetail.trim().isNotEmpty)
        extraDetail.trim(),
      if (nextStepQuestion != null && nextStepQuestion.trim().isNotEmpty)
        nextStepQuestion.trim(),
    ];
    return parts.join(' ');
  }

  String _perimeterPromptLabel() =>
      perimeterClear ? 'perimeter clear' : 'perimeter alert active';

  String _channelFaultPromptLabel() {
    final labels = knownFaultChannels
        .map((value) => 'Channel $value')
        .join(', ');
    final noun = knownFaultChannels.length == 1
        ? 'known fault on'
        : 'known faults on';
    return '$noun $labels';
  }

  String _channelFaultStatusLine() {
    return knownFaultChannels
        .map((value) => 'Channel $value offline (known fault)')
        .join(' • ');
  }

  String _presenceSummaryLabel() {
    final parts = <String>[
      if (humanCount > 0) _countLabel(humanCount, 'person'),
      if (vehicleCount > 0) _countLabel(vehicleCount, 'vehicle'),
      if (animalCount > 0) _countLabel(animalCount, 'animal'),
    ];
    if (parts.isEmpty) {
      return 'No people detected';
    }
    return '${parts.join(' • ')} detected';
  }

  String _relativeAgeLabel() {
    final difference = DateTime.now().toUtc().difference(observedAtUtc).abs();
    if (difference < const Duration(minutes: 1)) {
      return 'just now';
    }
    if (difference < const Duration(hours: 1)) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference < const Duration(days: 1)) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    final days = difference.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }

  static String _countLabel(int count, String singular) {
    final plural = singular == 'person' ? 'people' : '${singular}s';
    final noun = count == 1 ? singular : plural;
    return '$count $noun';
  }
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
    List<String> preferredReplyStyleTags = const <String>[],
    List<String> learnedReplyExamples = const <String>[],
    List<String> learnedReplyStyleTags = const <String>[],
    List<String> recentConversationTurns = const <String>[],
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
    String? siteAwarenessContext,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
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
    List<String> preferredReplyStyleTags = const <String>[],
    List<String> learnedReplyExamples = const <String>[],
    List<String> learnedReplyStyleTags = const <String>[],
    List<String> recentConversationTurns = const <String>[],
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
    String? siteAwarenessContext,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
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
        preferredReplyStyleTags: preferredReplyStyleTags,
        learnedReplyStyleTags: learnedReplyStyleTags,
        recentConversationTurns: recentConversationTurns,
        cameraHealthFactPacket: cameraHealthFactPacket,
        siteAwarenessSummary: siteAwarenessSummary,
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
    this.requestTimeout = const Duration(seconds: 5),
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
    List<String> preferredReplyStyleTags = const <String>[],
    List<String> learnedReplyExamples = const <String>[],
    List<String> learnedReplyStyleTags = const <String>[],
    List<String> recentConversationTurns = const <String>[],
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
    String? siteAwarenessContext,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
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
          preferredReplyStyleTags: preferredReplyStyleTags,
          learnedReplyStyleTags: learnedReplyStyleTags,
          recentConversationTurns: recentConversationTurns,
          cameraHealthFactPacket: cameraHealthFactPacket,
          siteAwarenessSummary: siteAwarenessSummary,
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
              'max_output_tokens': 500,
              'input': [
                {
                  'role': 'system',
                  'content': [
                    {
                      'type': 'input_text',
                      'text': _telegramAssistantSystemPrompt(
                        audience: audience,
                        scope: scope,
                        messageText: cleaned,
                        deliveryMode: deliveryMode,
                        clientProfileSignals: clientProfileSignals,
                        preferredReplyExamples: preferredReplyExamples,
                        preferredReplyStyleTags: preferredReplyStyleTags,
                        learnedReplyExamples: learnedReplyExamples,
                        learnedReplyStyleTags: learnedReplyStyleTags,
                        recentConversationTurns: recentConversationTurns,
                        cameraHealthFactPacket: cameraHealthFactPacket,
                        siteAwarenessContext: siteAwarenessContext,
                        siteAwarenessSummary: siteAwarenessSummary,
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
            preferredReplyStyleTags: preferredReplyStyleTags,
            learnedReplyStyleTags: learnedReplyStyleTags,
            recentConversationTurns: recentConversationTurns,
            cameraHealthFactPacket: cameraHealthFactPacket,
            siteAwarenessSummary: siteAwarenessSummary,
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
            preferredReplyStyleTags: preferredReplyStyleTags,
            learnedReplyStyleTags: learnedReplyStyleTags,
            recentConversationTurns: recentConversationTurns,
            cameraHealthFactPacket: cameraHealthFactPacket,
            siteAwarenessSummary: siteAwarenessSummary,
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
        preferredReplyStyleTags: preferredReplyStyleTags,
        learnedReplyExamples: learnedReplyExamples,
        learnedReplyStyleTags: learnedReplyStyleTags,
        recentConversationTurns: recentConversationTurns,
        cameraHealthFactPacket: cameraHealthFactPacket,
        siteAwarenessSummary: siteAwarenessSummary,
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
            preferredReplyStyleTags: preferredReplyStyleTags,
            learnedReplyStyleTags: learnedReplyStyleTags,
            recentConversationTurns: recentConversationTurns,
            cameraHealthFactPacket: cameraHealthFactPacket,
            siteAwarenessSummary: siteAwarenessSummary,
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
    } catch (error, stackTrace) {
      developer.log(
        'Telegram AI assistant request failed.',
        name: 'TelegramAiAssistantService',
        error: error,
        stackTrace: stackTrace,
      );
      return TelegramAiDraftReply(
        text: _fallbackReply(
          audience: audience,
          messageText: cleaned,
          scope: scope,
          deliveryMode: deliveryMode,
          clientProfileSignals: clientProfileSignals,
          preferredReplyExamples: preferredReplyExamples,
          preferredReplyStyleTags: preferredReplyStyleTags,
          learnedReplyStyleTags: learnedReplyStyleTags,
          recentConversationTurns: recentConversationTurns,
          cameraHealthFactPacket: cameraHealthFactPacket,
          siteAwarenessSummary: siteAwarenessSummary,
        ),
        usedFallback: true,
        usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
      );
    }
  }
}

class OnyxFirstTelegramAiAssistantService
    implements TelegramAiAssistantService {
  final OnyxAgentCloudBoostService onyxCloudBoost;
  final OnyxAgentLocalBrainService onyxLocalBrain;
  final TelegramAiAssistantService directProvider;

  const OnyxFirstTelegramAiAssistantService({
    required this.onyxCloudBoost,
    required this.onyxLocalBrain,
    required this.directProvider,
  });

  @override
  bool get isConfigured =>
      onyxCloudBoost.isConfigured ||
      onyxLocalBrain.isConfigured ||
      directProvider.isConfigured;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    List<String> clientProfileSignals = const <String>[],
    List<String> preferredReplyExamples = const <String>[],
    List<String> preferredReplyStyleTags = const <String>[],
    List<String> learnedReplyExamples = const <String>[],
    List<String> learnedReplyStyleTags = const <String>[],
    List<String> recentConversationTurns = const <String>[],
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
    String? siteAwarenessContext,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
  }) async {
    final cleaned = messageText.trim();
    final scope = _scopeProfileFor(clientId: clientId, siteId: siteId);
    if (cleaned.isEmpty) {
      return TelegramAiDraftReply(
        text: _emptyPromptReply(audience: audience, scope: scope),
        usedFallback: true,
        providerLabel: 'fallback',
        usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
      );
    }

    final onyxScope = OnyxAgentCloudScope(
      clientId: scope.clientId,
      siteId: scope.siteId,
      sourceRouteLabel: audience == TelegramAiAudience.admin
          ? 'Telegram Admin Reply'
          : 'Telegram Client Reply',
    );
    final prompt = _telegramAssistantOnyxPrompt(
      audience: audience,
      scope: scope,
      messageText: cleaned,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyExamples: learnedReplyExamples,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
      siteAwarenessContext: siteAwarenessContext,
      siteAwarenessSummary: siteAwarenessSummary,
    );
    final contextSummary = _telegramAssistantOnyxContextSummary(
      audience: audience,
      messageText: cleaned,
      deliveryMode: deliveryMode,
      recentConversationTurns: recentConversationTurns,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
      cameraHealthFactPacket: cameraHealthFactPacket,
      siteAwarenessSummary: siteAwarenessSummary,
    );

    if (onyxCloudBoost.isConfigured) {
      try {
        final cloudResponse = await onyxCloudBoost
            .boost(
              prompt: prompt,
              scope: onyxScope,
              intent: _onyxIntentForTelegramAudience(audience),
              contextSummary: contextSummary,
            )
            .timeout(const Duration(seconds: 5));
        final cloudDraft = _telegramDraftReplyFromOnyxResponse(
          response: cloudResponse,
          providerPrefix: 'onyx-cloud',
          audience: audience,
          messageText: cleaned,
          scope: scope,
          deliveryMode: deliveryMode,
          clientProfileSignals: clientProfileSignals,
          preferredReplyExamples: preferredReplyExamples,
          preferredReplyStyleTags: preferredReplyStyleTags,
          learnedReplyExamples: learnedReplyExamples,
          learnedReplyStyleTags: learnedReplyStyleTags,
          recentConversationTurns: recentConversationTurns,
          cameraHealthFactPacket: cameraHealthFactPacket,
          siteAwarenessSummary: siteAwarenessSummary,
        );
        if (cloudDraft != null) {
          return cloudDraft;
        }
      } catch (error, stackTrace) {
        developer.log(
          'Telegram AI cloud tier failed — falling through to next tier.',
          name: 'OnyxFirstTelegramAiAssistantService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (directProvider.isConfigured) {
      try {
        return await directProvider
            .draftReply(
              audience: audience,
              messageText: cleaned,
              clientId: clientId,
              siteId: siteId,
              deliveryMode: deliveryMode,
              clientProfileSignals: clientProfileSignals,
              preferredReplyExamples: preferredReplyExamples,
              preferredReplyStyleTags: preferredReplyStyleTags,
              learnedReplyExamples: learnedReplyExamples,
              learnedReplyStyleTags: learnedReplyStyleTags,
              recentConversationTurns: recentConversationTurns,
              cameraHealthFactPacket: cameraHealthFactPacket,
              siteAwarenessContext: siteAwarenessContext,
              siteAwarenessSummary: siteAwarenessSummary,
            )
            .timeout(const Duration(seconds: 5));
      } catch (error, stackTrace) {
        developer.log(
          'Telegram AI direct provider tier failed — falling through to next tier.',
          name: 'OnyxFirstTelegramAiAssistantService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (onyxLocalBrain.isConfigured) {
      try {
        final localResponse = await onyxLocalBrain
            .synthesize(
              prompt: prompt,
              scope: onyxScope,
              intent: _onyxIntentForTelegramAudience(audience),
              contextSummary: contextSummary,
            )
            .timeout(const Duration(seconds: 5));
        final localDraft = _telegramDraftReplyFromOnyxResponse(
          response: localResponse,
          providerPrefix: 'onyx-local',
          audience: audience,
          messageText: cleaned,
          scope: scope,
          deliveryMode: deliveryMode,
          clientProfileSignals: clientProfileSignals,
          preferredReplyExamples: preferredReplyExamples,
          preferredReplyStyleTags: preferredReplyStyleTags,
          learnedReplyExamples: learnedReplyExamples,
          learnedReplyStyleTags: learnedReplyStyleTags,
          recentConversationTurns: recentConversationTurns,
          cameraHealthFactPacket: cameraHealthFactPacket,
          siteAwarenessSummary: siteAwarenessSummary,
        );
        if (localDraft != null) {
          return localDraft;
        }
      } catch (error, stackTrace) {
        developer.log(
          'Telegram AI local brain tier failed — falling through to fallback.',
          name: 'OnyxFirstTelegramAiAssistantService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return const UnconfiguredTelegramAiAssistantService().draftReply(
      audience: audience,
      messageText: cleaned,
      clientId: clientId,
      siteId: siteId,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyExamples: learnedReplyExamples,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
      siteAwarenessContext: siteAwarenessContext,
      siteAwarenessSummary: siteAwarenessSummary,
    );
  }
}

String _telegramAssistantSystemPrompt({
  required TelegramAiAudience audience,
  required _TelegramAiScopeProfile scope,
  required String messageText,
  required TelegramAiDeliveryMode deliveryMode,
  List<String> clientProfileSignals = const <String>[],
  List<String> preferredReplyExamples = const <String>[],
  List<String> preferredReplyStyleTags = const <String>[],
  List<String> learnedReplyExamples = const <String>[],
  List<String> learnedReplyStyleTags = const <String>[],
  List<String> recentConversationTurns = const <String>[],
  ClientCameraHealthFactPacket? cameraHealthFactPacket,
  String? siteAwarenessContext,
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  final recentContext = _recentConversationContextSnippet(
    recentConversationTurns,
  );
  final preferredExamplesSnippet = _preferredReplyExamplesSnippet(
    preferredReplyExamples,
  );
  final preferredStyleTagsSnippet = _replyStyleTagsSnippet(
    preferredReplyStyleTags,
  );
  final learnedExamplesSnippet = _learnedReplyExamplesSnippet(
    learnedReplyExamples,
  );
  final learnedStyleTagsSnippet = _replyStyleTagsSnippet(learnedReplyStyleTags);
  final cameraHealthSnippet = _cameraHealthPromptSnippet(
    cameraHealthFactPacket,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  final clientPromptContext = _telegramAiClientPromptContext(
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
    siteAwarenessSummary: siteAwarenessSummary,
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
          '$cameraHealthSnippet'
          '${siteAwarenessContext != null && siteAwarenessContext.trim().isNotEmpty ? 'Site awareness snapshot:\n$siteAwarenessContext\n' : ''}'
          'Recent lane context:\n'
          '$recentContext';
    case TelegramAiAudience.client:
      final normalizedMessage = telegramAiNormalizeReplyHeuristicText(messageText);
      final tonePack = _clientTonePackFor(scope);
      final clientProfile = _clientProfileFromSignalsAndTags(
        clientProfileSignals: clientProfileSignals,
        preferredReplyStyleTags: preferredReplyStyleTags,
        learnedReplyStyleTags: learnedReplyStyleTags,
      );
      final laneStage = _resolveClientLaneStage(
        normalizedMessage: normalizedMessage,
        recentConversationTurns: recentConversationTurns,
      );
      final intent = _resolveClientReplyIntent(
        normalizedMessage,
        recentConversationTurns,
      );
      final includeGuardContext =
          clientPromptContext.guardOnSite == 'true' ||
          clientPromptContext.lastGuardCheckin != 'unknown';
      final laneGuidance = <String?>[
        if (_isEscalatedLaneContext(
          normalizedMessage: normalizedMessage,
          recentConversationTurns: recentConversationTurns,
        ))
          '- This lane is already escalated/high-priority.',
        if (_isPressuredLaneContext(
          normalizedMessage: normalizedMessage,
          recentConversationTurns: recentConversationTurns,
        ))
          '- This lane has repeated anxious follow-ups. Keep the reply steady and grounding.',
        if (laneStage == _ClientLaneStage.responderOnSite)
          '- Security is already on site, so answer as already on site and not ETA.',
        if (deliveryMode == TelegramAiDeliveryMode.approvalDraft)
          '- This reply is being drafted for operator approval.',
        switch (clientProfile) {
          _ClientProfile.conciseUpdates =>
            '- Client prefers short operational updates.',
          _ClientProfile.formalOperations =>
            '- Client prefers formal operations language.',
          _ClientProfile.reassuranceForward =>
            '- Client responds well to warm reassurance when pressure rises.',
          _ClientProfile.validationHeavy =>
            '- Client values concrete validation over generic reassurance.',
          _ClientProfile.standard => null,
        },
        switch (tonePack) {
          _ClientTonePack.residential =>
            '- Treat this as a residential/private-community lane.',
          _ClientTonePack.enterprise =>
            '- Treat this as a corporate/enterprise site.',
          _ClientTonePack.standard => null,
        },
        if (intent == _ClientReplyIntent.visual &&
            tonePack == _ClientTonePack.residential)
          '- This is a camera/daylight validation reply. Be protective and clear.',
        if (intent == _ClientReplyIntent.access &&
            tonePack == _ClientTonePack.enterprise)
          '- This is an access control reply. Focus on operational next steps.',
      ].whereType<String>().toList(growable: false);
      final additionalContextBlocks = <String>[
        'RECENT THREAD CONTEXT:\n$recentContext',
        if (laneGuidance.isNotEmpty)
          'LANE GUIDANCE:\n${laneGuidance.join('\n')}',
        if (preferredStyleTagsSnippet != null)
          'Preferred style cues for this lane right now:\n$preferredStyleTagsSnippet\nUse these to nudge the tone without copying them word-for-word.',
        if (preferredExamplesSnippet != null)
          'Preferred approved reply examples:\n$preferredExamplesSnippet',
        if (learnedStyleTagsSnippet != null)
          'Learned lane style tags:\n$learnedStyleTagsSnippet\nUse these to nudge the tone when they still fit.',
        if (learnedExamplesSnippet != null)
          'Learned strong reply examples:\n$learnedExamplesSnippet\nThese worked well in this lane before.',
        if (cameraHealthSnippet.isNotEmpty)
          'INTERNAL STATUS FACTS (do not quote raw labels or internal jargon verbatim):\n$cameraHealthSnippet',
        if (siteAwarenessContext != null &&
            siteAwarenessContext.trim().isNotEmpty)
          'VERIFIED LIVE SITE-AWARENESS FACTS (these come from the latest fresh site snapshot. Use them directly for current-status replies. State the perimeter status, people count, channel faults, and alert state plainly when relevant):\n$siteAwarenessContext',
      ];
      final additionalContext = additionalContextBlocks.join('\n\n');
      return 'You are ONYX, an AI-powered security intelligence system. You communicate directly with property owners and clients on behalf of their security monitoring service.\n\n'
          'IDENTITY:\n'
          '- You are ONYX Security Intelligence\n'
          '- You are calm, professional, and reassuring\n'
          '- You never panic, never speculate wildly\n'
          '- You speak like a competent security professional not like a chatbot\n\n'
          'CURRENT CONTEXT (injected per message):\n'
          '- Client: ${clientPromptContext.clientName}\n'
          '- Site: ${clientPromptContext.siteName}\n'
          '- Watch status: ${clientPromptContext.watchStatus}\n'
          '- Camera status: ${clientPromptContext.cameraStatus}\n'
          '- Active incidents: ${clientPromptContext.activeIncidents}\n'
          '- Last verified activity: ${clientPromptContext.lastActivity}\n'
          '${includeGuardContext ? '- Guard on site: ${clientPromptContext.guardOnSite}\n- Last guard check-in: ${clientPromptContext.lastGuardCheckin}\n' : ''}\n'
          'COMMUNICATION RULES:\n'
          '1. Never say "I cannot" - say what you CAN do\n'
          '2. If verified live site-awareness facts are present, treat them as the authoritative monitoring status. A fresh site snapshot means monitoring is active even if the browser camera bridge is degraded.\n'
          '3. Never promise dispatch without confirmation\n'
          '4. Never claim certainty you do not have\n'
          '5. Always end with a clear next step\n'
          '6. Only say "remote monitoring is limited right now" when there is no fresh live site snapshot.\n'
          '7. If asked about cameras and there is no fresh live site snapshot:\n'
          '   "I don\'t have live visual right now but I\'m monitoring all signals. What would you like me to check?"\n'
          '8. If asked for current status and verified live site-awareness facts are present:\n'
          '   "Monitoring active at MS Vallee Residence. Perimeter: Clear. On site: 1 person detected. Active alerts: None. Last update: 2 minutes ago. Channel status: Channel 11 offline (known fault). Want me to check anything specific?"\n'
          '9. If asked if everything is fine and you do not have full visibility:\n'
          '   "Based on what I can see, there are no active alerts. My visual monitoring is limited right now - want me to arrange a manual follow-up?"\n'
          '10. Keep responses under 3 sentences unless the situation requires more detail\n'
          '11. Never use technical jargon (no "DVR", "RTSP", "API" etc.)\n'
          '12. Match the client\'s energy - if they are worried, be more detailed. If casual, be brief.\n'
          '13. When verified live site-awareness facts are present, ground the reply in those facts first. If the user asks for status, say the current perimeter state, people count, alert state, and any channel faults in plain language before offering a next step.\n\n'
          'TONE EXAMPLES:\n\n'
          'Bad: "Camera visibility unavailable at [CLIENT_NAME] right now."\n\n'
          'Good: "I don\'t have full visual right now but I\'m watching all alarm signals. Everything looks quiet. Anything specific you\'d like me to check?"\n\n'
          'Bad: "I do not see a confirmed issue at [CLIENT_NAME] right now."\n\n'
          'Good: "Nothing flagged right now. Last activity was [X] - looked routine. What\'s on your mind?"\n\n'
          'Bad: "Remote monitoring is unavailable."\n\n'
          'Good: "Monitoring active at MS Vallee Residence. Perimeter: Clear. On site: 1 person detected. Active alerts: None. Last update: 2 minutes ago. Channel status: All reporting channels healthy. Want me to check anything specific?"\n\n'
          'INCIDENT RESPONSE TONE:\n'
          '- Confirmed threat: Direct, clear, action-focused\n'
          '  "There\'s activity at your North Gate. Control has been alerted. I\'m watching it now."\n'
          '- Possible threat: Honest, measured\n'
          '  "Something triggered at your perimeter. Could be nothing - I\'m checking it now."\n'
          '- False alarm: Reassuring, brief\n'
          '  "All clear. That was [cause]. Everything looks good."\n\n'
          'WHAT YOU KNOW:\n'
          '- Current incident status\n'
          '- On-site response coverage and last check-in when available\n'
          '- Camera and alarm status\n'
          '- Recent event history\n'
          '- Site layout and zone names\n\n'
          'WHAT YOU DON\'T CLAIM TO KNOW:\n'
          '- Anything outside your data feeds\n'
          '- Certainty about ambiguous situations\n'
          '- Outcomes before they are confirmed\n'
          '${additionalContext.isEmpty ? '' : '\n\nADDITIONAL INTERNAL CONTEXT (do not quote raw labels or internal codes verbatim):\n$additionalContext'}';
  }
}

String _cameraHealthPromptSnippet(
  ClientCameraHealthFactPacket? cameraHealthFactPacket, {
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  if (cameraHealthFactPacket == null) {
    return '';
  }
  final preamble = siteAwarenessSummary == null
      ? 'Structured camera health facts. Treat these as source-of-truth for camera-access claims, restoration claims, and next-step wording. Do not contradict them.'
      : 'Structured browser camera-health facts. These explain the local bridge state, but the fresh live site snapshot overrides them for whether monitoring is active.';
  return '$preamble\n'
      '${cameraHealthFactPacket.toPromptBlock()}\n';
}

_TelegramAiClientPromptContext _telegramAiClientPromptContext({
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  final joinedContext = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  return _TelegramAiClientPromptContext(
    clientName: _promptValueOrUnknown(scope.clientLabel),
    siteName: _promptValueOrUnknown(scope.siteReference),
    watchStatus: _telegramAiWatchStatusPromptValue(
      cameraHealthFactPacket,
      siteAwarenessSummary: siteAwarenessSummary,
    ),
    cameraStatus: _telegramAiCameraStatusPromptValue(
      cameraHealthFactPacket,
      siteAwarenessSummary: siteAwarenessSummary,
    ),
    activeIncidents: _telegramAiActiveIncidentsPromptValue(
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
      siteAwarenessSummary: siteAwarenessSummary,
    ),
    lastActivity: _telegramAiLastActivityPromptValue(
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
      siteAwarenessSummary: siteAwarenessSummary,
    ),
    guardOnSite: _telegramAiGuardOnSitePromptValue(joinedContext),
    lastGuardCheckin: _telegramAiLastGuardCheckinPromptValue(
      recentConversationTurns,
    ),
  );
}

String _promptValueOrUnknown(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? 'unknown' : normalized;
}

String _telegramAiWatchStatusPromptValue(
  ClientCameraHealthFactPacket? cameraHealthFactPacket, {
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  if (siteAwarenessSummary != null) {
    return siteAwarenessSummary.watchStatusPromptValue;
  }
  final packet = cameraHealthFactPacket;
  if (packet == null) {
    return 'unknown';
  }
  final watchStatus = (packet.continuousVisualWatchStatus ?? '').trim();
  final watchSummary = (packet.continuousVisualWatchSummary ?? '').trim();
  if (packet.hasContinuousVisualCoverage ||
      packet.hasActiveContinuousVisualChange ||
      packet.hasOngoingContinuousVisualChange) {
    return 'available';
  }
  if (watchStatus.isNotEmpty ||
      watchSummary.isNotEmpty ||
      packet.hasCurrentVisualConfirmation ||
      packet.hasRecentMovementSignals ||
      packet.hasRecentSiteIssueSignals ||
      packet.hasLiveVisualAccess) {
    return 'limited';
  }
  if (packet.status == ClientCameraHealthStatus.offline) {
    return 'offline';
  }
  return 'unknown';
}

String _telegramAiCameraStatusPromptValue(
  ClientCameraHealthFactPacket? cameraHealthFactPacket, {
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  if (siteAwarenessSummary != null) {
    return siteAwarenessSummary.cameraStatusPromptValue;
  }
  final packet = cameraHealthFactPacket;
  if (packet == null) {
    return 'unknown';
  }
  return switch (packet.status) {
    ClientCameraHealthStatus.live => 'available',
    ClientCameraHealthStatus.limited => 'limited',
    ClientCameraHealthStatus.offline => 'offline',
  };
}

String _telegramAiActiveIncidentsPromptValue({
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  if (siteAwarenessSummary != null) {
    return siteAwarenessSummary.activeIncidentsPromptValue;
  }
  final threadCount = _telegramAiOpenIncidentCount(recentConversationTurns);
  final packet = cameraHealthFactPacket;
  if (packet != null) {
    final issueLabel =
        packet.operatorIssueSignalLabel() ??
        packet.recentMovementSignalLabel?.trim() ??
        packet.recentMovementHotspotLabel?.trim();
    if (packet.hasActiveSiteIssueSignals) {
      final activeCount = threadCount ?? 1;
      return '$activeCount active - ${_promptValueOrUnknown(issueLabel)}';
    }
    if (packet.hasRecentSiteIssueSignals) {
      final activeCount = threadCount ?? 0;
      return '$activeCount active - recent activity: ${_promptValueOrUnknown(issueLabel)}';
    }
    if (packet.hasNoConfirmedSiteIssue ||
        packet.hasNoConfirmedMovement ||
        threadCount == 0) {
      return '0 active - no active alerts from current signals';
    }
  }
  if (threadCount != null) {
    if (threadCount <= 0) {
      return '0 active - no active alerts from recent thread context';
    }
    return '$threadCount active - recent thread context requires review';
  }
  return 'unknown';
}

String _telegramAiLastActivityPromptValue({
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  if (siteAwarenessSummary != null) {
    return siteAwarenessSummary.lastActivityPromptValue;
  }
  final packet = cameraHealthFactPacket;
  if (packet != null) {
    final activityLabel =
        packet.recentMovementSignalLabel?.trim().isNotEmpty == true
        ? packet.recentMovementSignalLabel!.trim()
        : packet.recentIssueSignalLabel?.trim().isNotEmpty == true
        ? packet.recentIssueSignalLabel!.trim()
        : packet.recentMovementHotspotLabel?.trim().isNotEmpty == true
        ? packet.recentMovementHotspotLabel!.trim()
        : null;
    if (activityLabel != null || packet.lastMovementSignalAtUtc != null) {
      return '${_promptTimestampValue(packet.lastMovementSignalAtUtc)} - ${_promptValueOrUnknown(activityLabel)}';
    }
  }
  for (final turn in recentConversationTurns) {
    final normalized = turn.trim();
    if (normalized.isEmpty) {
      continue;
    }
    final lower = normalized.toLowerCase();
    if (lower.contains('latest field signal:')) {
      final label = normalized.split(':').last.trim();
      return '${_promptTimestampValue(_extractTimestampFromPromptContext(normalized))} - ${_promptValueOrUnknown(label)}';
    }
    if (lower.contains('activity') || lower.contains('incident')) {
      return '${_promptTimestampValue(_extractTimestampFromPromptContext(normalized))} - ${_promptValueOrUnknown(normalized)}';
    }
  }
  return 'unknown';
}

String _telegramAiGuardOnSitePromptValue(String joinedContext) {
  if (joinedContext.trim().isEmpty) {
    return 'unknown';
  }
  if (_hasExplicitCurrentOnSitePresence(joinedContext)) {
    return 'true';
  }
  if (telegramAiContainsAny(joinedContext, const [
    'no guard is confirmed on site',
    'guard is not on site',
    'security is not on site',
    'security not on site',
    'security is not there',
    'security isnt there',
  ])) {
    return 'false';
  }
  return 'unknown';
}

String _telegramAiLastGuardCheckinPromptValue(
  List<String> recentConversationTurns,
) {
  for (final turn in recentConversationTurns) {
    final normalized = turn.trim();
    if (normalized.isEmpty) {
      continue;
    }
    final lower = normalized.toLowerCase();
    if (lower.contains('guard check-in')) {
      return _promptTimestampValue(_extractTimestampFromPromptContext(turn));
    }
  }
  return 'unknown';
}

int? _telegramAiOpenIncidentCount(List<String> recentConversationTurns) {
  final patterns = <RegExp>[
    RegExp(r'open incidents:\s*(\d+)', caseSensitive: false),
    RegExp(r'open follow-ups:\s*(\d+)', caseSensitive: false),
    RegExp(r'\bincidents:\s*(\d+)', caseSensitive: false),
    RegExp(r'\binc=(\d+)', caseSensitive: false),
  ];
  for (final turn in recentConversationTurns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(turn);
      final count = int.tryParse(match?.group(1) ?? '');
      if (count != null) {
        return count;
      }
    }
  }
  return null;
}

DateTime? _extractTimestampFromPromptContext(String text) {
  final isoMatch = RegExp(
    r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z)',
  ).firstMatch(text);
  if (isoMatch != null) {
    return DateTime.tryParse(isoMatch.group(1)!);
  }
  return null;
}

String _promptTimestampValue(DateTime? value) {
  return value?.toUtc().toIso8601String() ?? 'unknown';
}

OnyxAgentCloudIntent _onyxIntentForTelegramAudience(
  TelegramAiAudience audience,
) {
  switch (audience) {
    case TelegramAiAudience.admin:
      return OnyxAgentCloudIntent.admin;
    case TelegramAiAudience.client:
      return OnyxAgentCloudIntent.client;
  }
}

String _telegramAssistantOnyxPrompt({
  required TelegramAiAudience audience,
  required _TelegramAiScopeProfile scope,
  required String messageText,
  required TelegramAiDeliveryMode deliveryMode,
  List<String> clientProfileSignals = const <String>[],
  List<String> preferredReplyExamples = const <String>[],
  List<String> preferredReplyStyleTags = const <String>[],
  List<String> learnedReplyExamples = const <String>[],
  List<String> learnedReplyStyleTags = const <String>[],
  List<String> recentConversationTurns = const <String>[],
  ClientCameraHealthFactPacket? cameraHealthFactPacket,
  String? siteAwarenessContext,
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  final sharedPrompt = _telegramAssistantSystemPrompt(
    audience: audience,
    scope: scope,
    messageText: messageText,
    deliveryMode: deliveryMode,
    clientProfileSignals: clientProfileSignals,
    preferredReplyExamples: preferredReplyExamples,
    preferredReplyStyleTags: preferredReplyStyleTags,
    learnedReplyExamples: learnedReplyExamples,
    learnedReplyStyleTags: learnedReplyStyleTags,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
    siteAwarenessContext: siteAwarenessContext,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  final audienceLabel = audience == TelegramAiAudience.admin
      ? 'admin'
      : 'client';
  return 'Draft a send-ready $audienceLabel Telegram reply.\n'
      'Use these Telegram reply rules exactly:\n'
      '$sharedPrompt\n\n'
      'User message:\n$messageText\n\n'
      'Return only the final reply text. Plain text only. No JSON, bullets, role labels, or markdown.';
}

String _telegramAssistantOnyxContextSummary({
  required TelegramAiAudience audience,
  required String messageText,
  required TelegramAiDeliveryMode deliveryMode,
  required List<String> recentConversationTurns,
  required List<String> preferredReplyStyleTags,
  required List<String> learnedReplyStyleTags,
  ClientCameraHealthFactPacket? cameraHealthFactPacket,
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  final normalizedMessage = telegramAiNormalizeReplyHeuristicText(messageText);
  final laneStage = _resolveClientLaneStage(
    normalizedMessage: normalizedMessage,
    recentConversationTurns: recentConversationTurns,
  );
  final intent = _resolveClientReplyIntent(
    normalizedMessage,
    recentConversationTurns,
  );
  final highlights = <String>[
    'telegram audience=${audience.name}',
    'delivery_mode=${deliveryMode.name}',
    'lane_stage=${laneStage.name}',
    'intent=${intent.name}',
    if (preferredReplyStyleTags.isNotEmpty)
      'preferred_style_tags=${preferredReplyStyleTags.join(', ')}',
    if (learnedReplyStyleTags.isNotEmpty)
      'learned_style_tags=${learnedReplyStyleTags.join(', ')}',
    if (cameraHealthFactPacket != null)
      'camera_health=${cameraHealthFactPacket.operatorSummary}',
    if (siteAwarenessSummary != null)
      'site_awareness=${siteAwarenessSummary.contextSummary}',
    if (recentConversationTurns.isNotEmpty)
      'recent_turns=${recentConversationTurns.take(4).join(' | ')}',
  ];
  return highlights.join(' • ');
}

TelegramAiDraftReply? _telegramDraftReplyFromOnyxResponse({
  required OnyxAgentCloudBoostResponse? response,
  required String providerPrefix,
  required TelegramAiAudience audience,
  required String messageText,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  List<String> clientProfileSignals = const <String>[],
  List<String> preferredReplyExamples = const <String>[],
  List<String> preferredReplyStyleTags = const <String>[],
  List<String> learnedReplyExamples = const <String>[],
  List<String> learnedReplyStyleTags = const <String>[],
  List<String> recentConversationTurns = const <String>[],
  ClientCameraHealthFactPacket? cameraHealthFactPacket,
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  if (response?.isError == true) {
    return null;
  }
  final rawText = response?.text.trim() ?? '';
  if (rawText.isEmpty) {
    return null;
  }
  if (audience == TelegramAiAudience.client &&
      _looksMechanicalClientReply(rawText)) {
    return null;
  }
  final polished = _polishReply(
    audience: audience,
    text: rawText,
    messageText: messageText,
    scope: scope,
    deliveryMode: deliveryMode,
    clientProfileSignals: clientProfileSignals,
    preferredReplyExamples: preferredReplyExamples,
    preferredReplyStyleTags: preferredReplyStyleTags,
    learnedReplyExamples: learnedReplyExamples,
    learnedReplyStyleTags: learnedReplyStyleTags,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
    siteAwarenessSummary: siteAwarenessSummary,
  ).trim();
  if (polished.isEmpty) {
    return null;
  }
  return TelegramAiDraftReply(
    text: polished,
    providerLabel: '$providerPrefix:${response!.providerLabel}',
    usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
  );
}

String _fallbackReply({
  required TelegramAiAudience audience,
  required String messageText,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  List<String> clientProfileSignals = const <String>[],
  List<String> preferredReplyExamples = const <String>[],
  List<String> preferredReplyStyleTags = const <String>[],
  List<String> learnedReplyStyleTags = const <String>[],
  List<String> recentConversationTurns = const <String>[],
  ClientCameraHealthFactPacket? cameraHealthFactPacket,
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
}) {
  final approvalContext = _approvalDraftPromptContext(
    messageText,
    deliveryMode: deliveryMode,
  );
  final normalized = telegramAiNormalizeReplyHeuristicText(
    _fallbackPrimaryMessageText(
      messageText: messageText,
      deliveryMode: deliveryMode,
    ),
  );
  final tonePack = _clientTonePackFor(scope);
  final clientProfile = _clientProfileFromSignalsAndTags(
    clientProfileSignals: clientProfileSignals,
    preferredReplyStyleTags: preferredReplyStyleTags,
    learnedReplyStyleTags: learnedReplyStyleTags,
  );
  final laneStage = _resolveClientLaneStage(
    normalizedMessage: normalized,
    recentConversationTurns: recentConversationTurns,
  );
  final preferredReplyStyle = _preferredReplyStyleFromExamplesAndTags(
    preferredReplyExamples: preferredReplyExamples,
    preferredReplyStyleTags: preferredReplyStyleTags,
    learnedReplyStyleTags: learnedReplyStyleTags,
  );
  final escalatedLane = _isEscalatedLaneContext(
    normalizedMessage: normalized,
    recentConversationTurns: recentConversationTurns,
  );
  final pressuredLane = _isPressuredLaneContext(
    normalizedMessage: normalized,
    recentConversationTurns: recentConversationTurns,
  );
  final intent = _resolveClientReplyIntent(normalized, recentConversationTurns);
  final closing = _clientFollowUpClosing(
    recentConversationTurns,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalated: escalatedLane,
    compressed: pressuredLane,
  );
  final cameraHealthReply = _cameraHealthFactPacketReply(
    normalizedMessage: normalized,
    scope: scope,
    deliveryMode: deliveryMode,
    recentConversationTurns: recentConversationTurns,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalatedLane: escalatedLane,
    pressuredLane: pressuredLane,
    cameraHealthFactPacket: cameraHealthFactPacket,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  if (cameraHealthReply != null) {
    return cameraHealthReply;
  }
  final semanticMovementIdentificationReply =
      _semanticMovementIdentificationReply(
        normalizedMessage: normalized,
        scope: scope,
        cameraHealthFactPacket: cameraHealthFactPacket,
        siteAwarenessSummary: siteAwarenessSummary,
      );
  if (semanticMovementIdentificationReply != null) {
    return semanticMovementIdentificationReply;
  }
  final currentFrameMovementClarifier = _currentFrameMovementClarifierReply(
    normalizedMessage: normalized,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
  );
  if (currentFrameMovementClarifier != null) {
    return currentFrameMovementClarifier;
  }
  final continuousVisualWatchMovementReply =
      _continuousVisualWatchMovementReply(
        normalizedMessage: normalized,
        scope: scope,
        recentConversationTurns: recentConversationTurns,
        cameraHealthFactPacket: cameraHealthFactPacket,
      );
  if (continuousVisualWatchMovementReply != null) {
    return continuousVisualWatchMovementReply;
  }
  final siteMovementStatusClarifier = _siteMovementStatusClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  if (siteMovementStatusClarifier != null) {
    return siteMovementStatusClarifier;
  }
  final cameraCoverageCorrection = _cameraCoverageCorrectionReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
  );
  if (cameraCoverageCorrection != null) {
    return cameraCoverageCorrection;
  }
  final currentSiteViewClarifier = _currentSiteViewClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  if (currentSiteViewClarifier != null) {
    return currentSiteViewClarifier;
  }
  final broadStatusClarifier = _packetGroundedBroadStatusReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  if (broadStatusClarifier != null) {
    return broadStatusClarifier;
  }
  final siteIssueStatusClarifier = _siteIssueStatusClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  if (siteIssueStatusClarifier != null) {
    return siteIssueStatusClarifier;
  }
  final eventVisualImageClarifier = _eventVisualImageClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
  );
  if (eventVisualImageClarifier != null) {
    return eventVisualImageClarifier;
  }
  final escalationCapabilityReply = _hypotheticalEscalationCapabilityReply(
    normalizedMessage: normalized,
    scope: scope,
  );
  if (escalationCapabilityReply != null) {
    return escalationCapabilityReply;
  }
  final presenceVerificationReply = _presenceVerificationReply(
    normalizedMessage: normalized,
    scope: scope,
    deliveryMode: deliveryMode,
    recentConversationTurns: recentConversationTurns,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalatedLane: escalatedLane,
    pressuredLane: pressuredLane,
  );
  if (presenceVerificationReply != null) {
    return presenceVerificationReply;
  }
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
  final fieldTelemetryClarifier = _fieldTelemetryCountClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalatedLane: escalatedLane,
    pressuredLane: pressuredLane,
  );
  if (fieldTelemetryClarifier != null) {
    return fieldTelemetryClarifier;
  }
  final telemetryDispatchClarifier = _telemetryDispatchClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalatedLane: escalatedLane,
    pressuredLane: pressuredLane,
  );
  if (telemetryDispatchClarifier != null) {
    return telemetryDispatchClarifier;
  }
  final cameraHealthStatusUpdate = _cameraHealthStatusUpdateReply(
    normalizedMessage: normalized,
    scope: scope,
    deliveryMode: deliveryMode,
    recentConversationTurns: recentConversationTurns,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalatedLane: escalatedLane,
    pressuredLane: pressuredLane,
    cameraHealthFactPacket: cameraHealthFactPacket,
  );
  if (cameraHealthStatusUpdate != null) {
    return cameraHealthStatusUpdate;
  }
  final cameraHealthReassurance = _cameraHealthReassuranceReply(
    normalizedMessage: normalized,
    scope: scope,
    deliveryMode: deliveryMode,
    recentConversationTurns: recentConversationTurns,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalatedLane: escalatedLane,
    pressuredLane: pressuredLane,
    cameraHealthFactPacket: cameraHealthFactPacket,
  );
  if (cameraHealthReassurance != null) {
    return cameraHealthReassurance;
  }
  final cameraOfflineSignalClarifier = _cameraOfflineSignalClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  if (cameraOfflineSignalClarifier != null) {
    return cameraOfflineSignalClarifier;
  }
  final historicalAlarmReviewReply = _historicalAlarmReviewReply(
    normalizedMessage: normalized,
    recentConversationTurns: recentConversationTurns,
  );
  if (historicalAlarmReviewReply != null) {
    return historicalAlarmReviewReply;
  }
  final correctionReply = _clientCorrectionClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalatedLane: escalatedLane,
    pressuredLane: pressuredLane,
  );
  if (correctionReply != null) {
    return correctionReply;
  }
  final operationalPictureReply = _operationalPictureClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
  );
  if (operationalPictureReply != null) {
    return operationalPictureReply;
  }
  final alertWatchReply = _alertWatchAcknowledgementReply(
    normalizedMessage: normalized,
    scope: scope,
  );
  if (alertWatchReply != null) {
    return alertWatchReply;
  }
  final cameraConnectionReply = _cameraConnectionClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  if (cameraConnectionReply != null) {
    return cameraConnectionReply;
  }
  final approvalDraftFallback = _approvalDraftFallbackReply(
    approvalContext: approvalContext,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    deliveryMode: deliveryMode,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    escalatedLane: escalatedLane,
    pressuredLane: pressuredLane,
  );
  if (approvalDraftFallback != null) {
    return approvalDraftFallback;
  }
  final cameraStatusClarifier = _cameraStatusClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    siteAwarenessSummary: siteAwarenessSummary,
  );
  if (cameraStatusClarifier != null) {
    return cameraStatusClarifier;
  }
  final remoteMonitoringRestorationReply = _remoteMonitoringRestorationReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
  );
  if (remoteMonitoringRestorationReply != null) {
    return remoteMonitoringRestorationReply;
  }
  final reassuranceClarifier = _reassuranceClarifierReply(
    normalizedMessage: normalized,
    scope: scope,
    recentConversationTurns: recentConversationTurns,
    laneStage: laneStage,
    tonePack: tonePack,
    preferredReplyStyle: preferredReplyStyle,
    clientProfile: clientProfile,
    deliveryMode: deliveryMode,
    escalatedLane: escalatedLane,
    pressuredLane: pressuredLane,
  );
  if (reassuranceClarifier != null) {
    return reassuranceClarifier;
  }
  if (laneStage == _ClientLaneStage.closure) {
    if (telegramAiContainsAny(normalized, const [
      'thank you',
      'thanks',
      'appreciate it',
    ])) {
      return _closureThanksReplyForTonePack(scope: scope, tonePack: tonePack);
    }
    if (intent == _ClientReplyIntent.access) {
      return _closureAccessReplyForTonePack(scope: scope, tonePack: tonePack);
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
      return 'This is already escalated for ${scope.siteReference}. ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.eta, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: true, compressed: pressuredLane)}';
    }
    return 'We are checking the ETA for ${scope.siteReference} now. ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.eta, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, clientProfile: clientProfile, escalated: escalatedLane, compressed: pressuredLane)}';
  }
  if (intent == _ClientReplyIntent.movement) {
    if (escalatedLane) {
      return 'This is already escalated for ${scope.siteReference}. ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.movement, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: true, compressed: pressuredLane)}';
    }
    return 'We are checking who is moving to ${scope.siteReference} now. ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.movement, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, escalated: escalatedLane, compressed: pressuredLane)}';
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
  if (telegramAiContainsAny(normalized, const [
    'thank you',
    'thanks',
    'appreciate it',
  ])) {
    if (deliveryMode == TelegramAiDeliveryMode.approvalDraft) {
      return 'You are welcome. We are still tracking ${scope.siteReference}, and I will keep this lane updated if anything changes.';
    }
    return _thanksReplyForTonePack(
      scope: scope,
      tonePack: tonePack,
      clientProfile: clientProfile,
    );
  }
  if (telegramAiContainsAny(normalized, const [
    'who are you',
    'are you ai',
    'are you a bot',
    'robot',
  ])) {
    return 'I am ONYX support for ${scope.siteReference}. I can help with updates, response status, and getting control involved quickly.';
  }
  if (escalatedLane) {
    return 'This is already escalated for ${scope.siteReference}. $closing';
  }
  return 'We are checking ${scope.siteReference} now. $closing';
}

String? _telegramCameraFactTimeLabel(DateTime? value) {
  if (value == null) {
    return null;
  }
  final utc = value.toUtc();
  final hh = utc.hour.toString().padLeft(2, '0');
  final mm = utc.minute.toString().padLeft(2, '0');
  return '$hh:$mm UTC';
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
  List<String> preferredReplyStyleTags = const <String>[],
  List<String> learnedReplyExamples = const <String>[],
  List<String> learnedReplyStyleTags = const <String>[],
  List<String> recentConversationTurns = const <String>[],
  ClientCameraHealthFactPacket? cameraHealthFactPacket,
  TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
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
  if (audience == TelegramAiAudience.client &&
      siteAwarenessSummary != null &&
      telegramAiContainsAny(cleaned.toLowerCase(), const [
        'monitoring is limited',
        'remote monitoring is limited',
        'remote visual monitoring is limited',
        'do not have live visual',
        'camera visibility is limited',
        'camera visibility unavailable',
        'remote monitoring is unavailable',
        'camera access issues',
        'camera access issue',
        'camera bridge is offline',
        'camera link is temporarily limited',
      ])) {
    return _fallbackReply(
      audience: audience,
      messageText: messageText,
      scope: scope,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
      siteAwarenessSummary: siteAwarenessSummary,
    );
  }
  if (audience == TelegramAiAudience.client &&
      deliveryMode == TelegramAiDeliveryMode.telegramLive &&
      _shouldForceTruthGroundedClientFallback(
        messageText: messageText,
        recentConversationTurns: recentConversationTurns,
      )) {
    return _fallbackReply(
      audience: audience,
      messageText: messageText,
      scope: scope,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
      siteAwarenessSummary: siteAwarenessSummary,
    );
  }
  if (_looksMechanicalClientReply(cleaned)) {
    return _fallbackReply(
      audience: audience,
      messageText: messageText,
      scope: scope,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
      siteAwarenessSummary: siteAwarenessSummary,
    );
  }
  cleaned = _dedupeClientReplySentences(cleaned);
  if (_shouldPreferFallbackForClientReply(
    messageText: messageText,
    replyText: cleaned,
    recentConversationTurns: recentConversationTurns,
    deliveryMode: deliveryMode,
    cameraHealthFactPacket: cameraHealthFactPacket,
  )) {
    return _fallbackReply(
      audience: audience,
      messageText: messageText,
      scope: scope,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
      siteAwarenessSummary: siteAwarenessSummary,
    );
  }
  final normalizedDrift = _normalizeClientReplyDrift(
    text: _simplifyClientReplyLanguage(cleaned),
    deliveryMode: deliveryMode,
    laneStage: _resolveClientLaneStage(
      normalizedMessage: telegramAiNormalizeReplyHeuristicText(messageText),
      recentConversationTurns: recentConversationTurns,
    ),
    preferredReplyStyle: _preferredReplyStyleFromExamplesAndTags(
      preferredReplyExamples: _combinedReplyExamples(
        preferredReplyExamples: preferredReplyExamples,
        learnedReplyExamples: learnedReplyExamples,
      ),
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
    ),
    clientProfile: _clientProfileFromSignalsAndTags(
      clientProfileSignals: clientProfileSignals,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
    ),
  );
  return _ensureClientReplyCompleteness(
    _dedupeClientReplySentences(normalizedDrift),
  );
}

bool _shouldForceTruthGroundedClientFallback({
  required String messageText,
  required List<String> recentConversationTurns,
}) {
  final normalizedMessage = telegramAiNormalizeReplyHeuristicText(messageText);
  if (normalizedMessage.isEmpty) {
    return false;
  }
  final joinedContext = recentConversationTurns
      .map(telegramAiNormalizeReplyHeuristicText)
      .where((value) => value.isNotEmpty)
      .join('\n');
  final simpleThanks =
      telegramAiContainsAny(normalizedMessage, const [
        'thank you',
        'thanks',
        'appreciate it',
      ]) &&
      !telegramAiContainsAny(normalizedMessage, const [
        'keep me posted',
        'keep me updated',
        'serious alerts',
        'serious alert',
        'anything serious',
      ]);
  if (simpleThanks) {
    return true;
  }
  if (_challengesTelemetryPresenceSummary(normalizedMessage)) {
    return true;
  }
  if (_asksHypotheticalEscalationCapability(normalizedMessage)) {
    return true;
  }
  final clientCorrection = telegramAiContainsAny(normalizedMessage, const [
    'my cameras are down',
    'cameras are down',
    'camera is down',
    'camera down',
    'cctv is down',
    'cctv down',
    'cameras are not offline',
    'camera is not offline',
    'cameras are not down',
    'camera is not down',
    'bridge is not offline',
    'camera bridge is not offline',
    'security is not on site',
    'security not on site',
    'security isnt on site',
    'security is not there',
    'security isnt there',
  ]);
  if (clientCorrection) {
    return true;
  }
  final operationalPictureClarifier =
      telegramAiContainsAny(normalizedMessage, const [
        'what current operational picture',
        'what operational picture',
        'what do you mean operational picture',
        'what picture',
      ]) &&
      telegramAiContainsAny(joinedContext, const [
        'current operational picture',
        'community reports',
        'live camera check',
      ]);
  if (operationalPictureClarifier) {
    return true;
  }
  if (_asksForCurrentSiteView(normalizedMessage) ||
      _asksForCurrentFrameMovementCheck(normalizedMessage) ||
      _asksForSemanticMovementIdentification(normalizedMessage) ||
      _asksForCurrentFramePersonConfirmation(normalizedMessage)) {
    return true;
  }
  final cameraConnectionAsk =
      telegramAiContainsAny(normalizedMessage, const [
        'why cant you see my cameras',
        'why can you not see my cameras',
        'why cant you see the cameras',
        'why can you not see the cameras',
        'rewire cameras',
        'rewire camera',
        'fix the cameras',
        'fix the camera',
        'check asap',
        'check as soon as possible',
        'repair the cameras',
        'repair the camera',
        'is the connection fixed',
        'is the camera connection fixed',
        'is the connection back',
        'are the cameras back',
        'is it back up',
      ]) &&
      telegramAiContainsAny(joinedContext, const [
        'temporarily without remote monitoring',
        'remote watch is temporarily unavailable',
        'remote monitoring is offline',
        'monitoring connection is offline',
        'offline for this site',
        'monitoring path is offline',
        'do not have live camera confirmation',
        'do not have live visual confirmation',
        'camera connection issue',
        'connection issue',
      ]);
  if (cameraConnectionAsk) {
    return true;
  }
  if (_isGenericStatusFollowUp(normalizedMessage) &&
      _hasRecentPresenceVerificationContext(joinedContext)) {
    return true;
  }
  final issueClarifierAsk = _asksForCurrentSiteIssueCheck(normalizedMessage);
  if (issueClarifierAsk &&
      (_hasRecentPresenceVerificationContext(joinedContext) ||
          _hasTelemetrySummaryContext(joinedContext))) {
    return true;
  }
  if ((_asksForCurrentFrameMovementCheck(normalizedMessage) ||
          _isGenericStatusFollowUp(normalizedMessage)) &&
      _hasRecentContinuousVisualActivityContext(joinedContext)) {
    return true;
  }
  final reassuranceAsk =
      asksForTelegramClientBroadStatusCheck(normalizedMessage) ||
      telegramAiContainsAny(normalizedMessage, const [
        'safe',
        'you sure',
        'are you sure',
      ]);
  if (!reassuranceAsk) {
    return false;
  }
  return telegramAiContainsAny(joinedContext, const [
    'site activity summary',
    'field telemetry',
    'latest field signal',
    'community reports',
    'suspicious vehicle scouting',
    'not sitting as an open incident',
    'remote monitoring is offline',
    'temporarily without remote monitoring',
    'do not have live visual confirmation',
    'current operational picture',
  ]);
}

bool _looksMechanicalClientReply(String text) {
  final normalized = text.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  if (telegramAiContainsAny(normalized, const [
    'received your message',
    'we have your message',
    'we have received your message',
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

bool _replyConflictsWithCameraHealthFactPacket({
  required String normalizedMessage,
  required String normalizedReply,
  required List<String> recentConversationTurns,
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final packet = cameraHealthFactPacket;
  if (packet == null) {
    return false;
  }
  final asksWhyNoCameras = _asksWhyNoLiveCameraAccess(normalizedMessage);
  final asksForUrgentCameraRepair = telegramAiContainsAny(normalizedMessage, const [
    'rewire cameras',
    'rewire camera',
    'fix the cameras',
    'fix the camera',
    'repair the cameras',
    'repair the camera',
    'reconnect cameras',
    'reconnect camera',
  ]);
  final asksIfConnectionIsFixed = _asksIfConnectionOrBridgeIsFixed(
    normalizedMessage,
  );
  final assertsLiveVisualAccess = _assertsLiveVisualAccessState(
    normalizedMessage,
  );
  final asksCameraCheck = telegramAiContainsAny(normalizedMessage, const [
    'did you check cameras',
    'did you check the cameras',
    'did you check camera',
    'camera check',
    'check cameras',
  ]);
  final genericStatusFollowUp = _isGenericStatusFollowUp(normalizedMessage);
  final camerasDown = telegramAiContainsAny(normalizedMessage, const [
    'my cameras are down',
    'cameras are down',
    'camera is down',
    'camera down',
    'cctv is down',
    'cctv down',
  ]);
  if (!asksWhyNoCameras &&
      !asksForUrgentCameraRepair &&
      !asksIfConnectionIsFixed &&
      !assertsLiveVisualAccess &&
      !genericStatusFollowUp &&
      !asksCameraCheck &&
      !camerasDown) {
    return false;
  }
  final joinedContext = recentConversationTurns
      .map(telegramAiNormalizeReplyHeuristicText)
      .where((value) => value.isNotEmpty)
      .join('\n');
  final hasRecentCameraContext = _hasRecentCameraStatusContext(joinedContext);
  final mentionsRestoredLiveAccess = telegramAiContainsAny(normalizedReply, const [
    'yes we currently have live camera access',
    'we currently have live camera access',
    'live camera access is up',
    'connection is restored',
    'connection restored',
    'back online',
    'back up',
  ]);
  final mentionsUnavailableAccess = telegramAiContainsAny(normalizedReply, const [
    'not confirmed yet',
    'cannot say',
    'currently unavailable',
    'currently limited',
    'do not have live camera',
    'do not have live visual',
    'no live stream access',
  ]);
  final mentionsLiveVisualConfirmation = telegramAiContainsAny(normalizedReply, const [
    'visual confirmation',
    'last successful visual confirmation',
    'live camera access',
    'live visual access',
  ]);
  final mentionsUnsafeRepairPromise = telegramAiContainsAny(normalizedReply, const [
    'rewire',
    're-wire',
    'send a technician',
    'technician will',
  ]);
  if (asksIfConnectionIsFixed) {
    if (packet.status == ClientCameraHealthStatus.live) {
      return !mentionsRestoredLiveAccess;
    }
    return mentionsRestoredLiveAccess || !mentionsUnavailableAccess;
  }
  if ((asksWhyNoCameras || asksCameraCheck || camerasDown) &&
      packet.status != ClientCameraHealthStatus.live) {
    return mentionsRestoredLiveAccess || !mentionsUnavailableAccess;
  }
  if (assertsLiveVisualAccess) {
    if (packet.status == ClientCameraHealthStatus.live) {
      return mentionsUnavailableAccess || !mentionsLiveVisualConfirmation;
    }
    return mentionsRestoredLiveAccess || !mentionsUnavailableAccess;
  }
  if (genericStatusFollowUp && hasRecentCameraContext) {
    if (packet.status == ClientCameraHealthStatus.live) {
      return mentionsUnavailableAccess || !mentionsLiveVisualConfirmation;
    }
    return mentionsRestoredLiveAccess || !mentionsUnavailableAccess;
  }
  if (asksWhyNoCameras &&
      packet.status == ClientCameraHealthStatus.live &&
      !mentionsLiveVisualConfirmation) {
    return true;
  }
  if (asksForUrgentCameraRepair &&
      packet.reason == ClientCameraHealthReason.credentialsMissing &&
      mentionsUnsafeRepairPromise) {
    return true;
  }
  return false;
}

bool _shouldPreferFallbackForClientReply({
  required String messageText,
  required String replyText,
  required List<String> recentConversationTurns,
  TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
  ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  final approvalContext = _approvalDraftPromptContext(
    messageText,
    deliveryMode: deliveryMode,
  );
  final normalizedMessage = telegramAiNormalizeReplyHeuristicText(
    _fallbackPrimaryMessageText(
      messageText: messageText,
      deliveryMode: deliveryMode,
    ),
  );
  final normalizedReply = telegramAiNormalizeReplyHeuristicText(replyText);
  final normalizedOperatorDraft = telegramAiNormalizeReplyHeuristicText(
    approvalContext.operatorDraft ?? '',
  );
  final normalizedClientAsk = telegramAiNormalizeReplyHeuristicText(
    approvalContext.clientAsk ?? '',
  );
  final joinedContext = recentConversationTurns
      .map(telegramAiNormalizeReplyHeuristicText)
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (normalizedMessage.isEmpty || normalizedReply.isEmpty) {
    return false;
  }
  final remoteMonitoringOffline = telegramAiContainsAny(joinedContext, const [
    'temporarily without remote monitoring',
    'remote watch is temporarily unavailable',
    'remote monitoring is offline',
    'monitoring connection is offline',
    'offline for this site',
    'monitoring path is offline',
  ]);
  final reassuranceClarifierAsk =
      asksForTelegramClientBroadStatusCheck(normalizedMessage) ||
      telegramAiContainsAny(normalizedMessage, const [
        'does that mean',
        'what does that mean',
        'safe',
        'secure',
        'you sure',
        'are you sure',
      ]);
  final restorationAsk = telegramAiContainsAny(normalizedMessage, const [
    'when will remote monitoring be back',
    'when will remote monitoring be back up',
    'when will remote monitoring be back online',
    'when will monitoring be back',
    'when will monitoring be back up',
    'when will monitoring be back online',
    'when will remote watch be back',
    'how long until remote monitoring',
    'how long until monitoring',
    'when is remote monitoring back',
  ]);
  final telemetrySummaryVisible = telegramAiContainsAny(joinedContext, const [
    'site activity summary',
    'field telemetry',
    'latest field signal:',
    'guard or response team activity signals were logged through onyx field telemetry',
    'guard or response team activity signal was logged through onyx field telemetry',
  ]);
  final noOpenIncident = telegramAiContainsAny(joinedContext, const [
    'not sitting as an open incident',
    'open follow ups 0',
    'open follow-ups: 0',
    'no client facing action has been required',
  ]);
  final telemetryPresenceChallenge = _challengesTelemetryPresenceSummary(
    '$normalizedMessage\n$normalizedClientAsk',
  );
  final fieldTelemetryCountChallenge =
      telemetryPresenceChallenge &&
      telegramAiContainsAny(joinedContext, const [
        'guard or response team activity signals were observed through onyx field telemetry',
        'guard or response team activity signal was observed through onyx field telemetry',
        'site activity summary',
      ]);
  final telemetryDispatchClarifierAsk =
      telemetryPresenceChallenge ||
      telegramAiContainsAny('$normalizedMessage\n$normalizedClientAsk', const [
        'there is no unit on site',
        'there isnt a unit on site',
        'there is no team on site',
        'there is no one on site',
        'no unit on site',
        'why are they coming',
        'why are you coming',
        'why is someone coming',
        'why coming here',
        'who is coming',
        'who is moving',
        'is there an issue',
        'is there a problem',
        'is something wrong',
        'issue at my site',
        'problem at my site',
      ]) ||
      normalizedMessage == 'why' ||
      normalizedMessage == 'why?';
  final issueClarifierAsk = _asksForCurrentSiteIssueCheck(
    '$normalizedMessage\n$normalizedClientAsk',
  );
  final gratitudeAlertWatch =
      telegramAiContainsAny(normalizedMessage, const [
        'thank you',
        'thanks',
        'appreciate it',
        'thank you for assisting',
      ]) &&
      telegramAiContainsAny(normalizedMessage, const [
        'keep me posted',
        'keep me updated',
        'serious alerts',
        'serious alert',
        'anything serious',
        'let me know if anything changes',
      ]);
  final cameraReassuranceAsk =
      telegramAiContainsAny(normalizedMessage, const [
        'did you check cameras',
        'did you check the cameras',
        'did you check camera',
        'camera check',
      ]) &&
      telegramAiContainsAny(normalizedMessage, const [
        'all good',
        'everything good',
        'everything okay',
        'safe',
        'okay',
        'ok',
      ]);
  final explicitOnSitePresence = _hasExplicitCurrentOnSitePresence(
    joinedContext,
  );
  final explicitMovementConfirmation = _hasExplicitCurrentMovementConfirmation(
    joinedContext,
  );
  final explicitLiveCameraAccess =
      !remoteMonitoringOffline &&
      telegramAiContainsAny(joinedContext, const [
        'latest camera picture',
        'camera check',
        'camera update',
        'live visual confirmation',
        'camera confirms',
        'reviewed items',
      ]);
  final genericPromiseReply =
      telegramAiContainsAny(normalizedReply, const ['we are checking']) &&
      telegramAiContainsAny(normalizedReply, const ['i will update you here']);
  final presenceVerificationFollowUp =
      _isGenericStatusFollowUp(normalizedMessage) &&
      _hasRecentPresenceVerificationContext(joinedContext);
  final continuousVisualWatchFollowUp =
      cameraHealthFactPacket?.hasOngoingContinuousVisualChange == true &&
      ((_asksForCurrentFrameMovementCheck(normalizedMessage) ||
              _asksForCurrentFramePersonConfirmation(normalizedMessage)) ||
          (_isGenericStatusFollowUp(normalizedMessage) &&
              _hasRecentContinuousVisualActivityContext(joinedContext))) &&
      !_hasCurrentFrameConversationContext(
        joinedContext,
        cameraHealthFactPacket: cameraHealthFactPacket,
      ) &&
      !_hasRecentMotionTelemetryContext(joinedContext);
  final camerasDownCorrection = telegramAiContainsAny(normalizedMessage, const [
    'my cameras are down',
    'cameras are down',
    'camera is down',
    'camera down',
    'cctv is down',
    'cctv down',
  ]);
  final securityNotOnSiteCorrection =
      telemetryPresenceChallenge ||
      telegramAiContainsAny(normalizedMessage, const [
        'security is not on site',
        'security not on site',
        'security isnt on site',
        'security is not there',
        'security isnt there',
        'there are no guards',
        'there is no guard',
        'no guards at',
        'no guards on',
        'not on site',
      ]);
  final operationalPictureClarifierAsk = telegramAiContainsAny(normalizedMessage, const [
    'what current operational picture',
    'what operational picture',
    'what do you mean operational picture',
    'what picture',
  ]);
  final cameraConnectionAsk =
      telegramAiContainsAny(normalizedMessage, const [
        'rewire cameras',
        'rewire camera',
        'fix the cameras',
        'fix the camera',
        'check asap',
        'check as soon as possible',
        'repair the cameras',
        'repair the camera',
      ]) ||
      _asksWhyNoLiveCameraAccess(normalizedMessage) ||
      _asksIfConnectionOrBridgeIsFixed(normalizedMessage);
  if (_replyConflictsWithCameraHealthFactPacket(
    normalizedMessage: normalizedMessage,
    normalizedReply: normalizedReply,
    recentConversationTurns: recentConversationTurns,
    cameraHealthFactPacket: cameraHealthFactPacket,
  )) {
    return true;
  }
  if (_asksHypotheticalEscalationCapability(normalizedMessage) &&
      telegramAiContainsAny(normalizedReply, const [
        'has been escalated to the control room now',
        'this has been escalated to the control room now',
        'move to safety if you can',
        'call saps or 112 now',
      ])) {
    return true;
  }
  if (presenceVerificationFollowUp) {
    final answersPresenceState = telegramAiContainsAny(normalizedReply, const [
      'no guard is confirmed on site',
      'confirmed guard on site',
      'response movement is confirmed toward',
      'recorded onyx telemetry activity',
      'verified position update',
      'current response position',
    ]);
    final driftsBackToCamera = telegramAiContainsAny(normalizedReply, const [
      'local camera bridge',
      'camera bridge',
      'live camera access',
      'visual confirmation',
      'monitoring path',
    ]);
    if (!answersPresenceState || genericPromiseReply || driftsBackToCamera) {
      return true;
    }
  }
  if (issueClarifierAsk && cameraHealthFactPacket != null) {
    switch (_effectiveLiveSiteIssueStatus(cameraHealthFactPacket)) {
      case ClientLiveSiteIssueStatus.activeSignals:
        final answersActiveIssueSignals = telegramAiContainsAny(normalizedReply, const [
          'i am seeing live activity around',
          'something active is happening there',
          'cannot confirm from this signal alone',
          'breach person or vehicle',
        ]);
        final driftsOrContradicts = telegramAiContainsAny(normalizedReply, const [
          'no confirmed active issue',
          'nothing in the current watch signals confirms an issue',
          'camera bridge is offline',
          'local camera bridge is offline',
          'cameras are currently offline',
        ]);
        if (!answersActiveIssueSignals || driftsOrContradicts) {
          return true;
        }
        break;
      case ClientLiveSiteIssueStatus.recentSignals:
        final answersRecentIssueSignals = telegramAiContainsAny(normalizedReply, const [
          'recent movement signals',
          'recent activity was picked up on site',
          'i am seeing',
          'do not yet have a confirmed active issue',
        ]);
        final driftsOrContradicts = telegramAiContainsAny(normalizedReply, const [
          'no confirmed active issue',
          'camera bridge is offline',
          'local camera bridge is offline',
          'cameras are currently offline',
          'nothing in the current watch signals confirms an issue',
        ]);
        if (!answersRecentIssueSignals || driftsOrContradicts) {
          return true;
        }
        break;
      case ClientLiveSiteIssueStatus.noConfirmedIssue:
      case ClientLiveSiteIssueStatus.unknown:
        final answersIssueState = telegramAiContainsAny(normalizedReply, const [
          'no confirmed active issue',
          'nothing in the current signals confirms an active issue',
          'nothing in the current signals confirms an issue',
          'current signals i can see right now',
        ]);
        final driftsToPresence = telegramAiContainsAny(normalizedReply, const [
          'guard presence on site',
          'confirmed guard presence on site',
          'no confirmed guard presence on site',
        ]);
        if (!answersIssueState || genericPromiseReply || driftsToPresence) {
          return true;
        }
        break;
    }
  }
  if (issueClarifierAsk &&
      (_hasRecentPresenceVerificationContext(joinedContext) ||
          telemetrySummaryVisible)) {
    final answersIssueState = telegramAiContainsAny(normalizedReply, const [
      'no confirmed active issue',
      'do not have a confirmed active issue',
      'recorded onyx field telemetry',
      'not a confirmed active dispatch',
      'current position',
    ]);
    final driftsToPresenceOrCamera = telegramAiContainsAny(normalizedReply, const [
      'guard presence on site',
      'confirmed guard presence on site',
      'no confirmed guard presence on site',
      'local bridge issue',
      'camera bridge',
      'live visual confirmation isnt available',
      'live visual confirmation is not available',
      'cameras are currently offline',
      'the cameras are currently offline',
    ]);
    if (!answersIssueState || genericPromiseReply || driftsToPresenceOrCamera) {
      return true;
    }
  }
  if (continuousVisualWatchFollowUp) {
    final answersVisualWatch = telegramAiContainsAny(normalizedReply, const [
      'i am seeing live activity around',
      'something active is happening there',
      'cannot confirm from this signal alone',
      'person vehicle or breach',
    ]);
    final overstatesOrContradicts = telegramAiContainsAny(normalizedReply, const [
      'no movement is currently detected',
      'nothing was detected',
      'camera bridge is offline',
      'local camera bridge is offline',
      'cannot confirm movement visually right now',
    ]);
    if (!answersVisualWatch || overstatesOrContradicts) {
      return true;
    }
  }
  if (gratitudeAlertWatch) {
    final answersGratitudeWatch = telegramAiContainsAny(normalizedReply, const [
      'you are welcome',
      'keep you posted',
      'update you here',
      'if anything serious comes through',
      'if anything serious happens',
      'if anything changes',
    ]);
    if (!answersGratitudeWatch ||
        telegramAiContainsAny(normalizedReply, const [
          'no unresolved incidents',
          'no active critical alerts',
        ])) {
      return true;
    }
  }
  final simpleThanks =
      telegramAiContainsAny(normalizedMessage, const [
        'thank you',
        'thanks',
        'appreciate it',
      ]) &&
      !gratitudeAlertWatch;
  if (simpleThanks) {
    final thanksReplyLooksRight = telegramAiContainsAny(normalizedReply, const [
      'you are welcome',
      'keep you posted',
      'update you',
      'if anything changes',
    ]);
    if (!thanksReplyLooksRight ||
        telegramAiContainsAny(normalizedReply, const [
          'everything is stable',
          'stable at the moment',
          'we are monitoring the situation',
        ])) {
      return true;
    }
  }
  if (remoteMonitoringOffline && reassuranceClarifierAsk) {
    final answersClearly = telegramAiContainsAny(normalizedReply, const [
      'not confirmed yet',
      'not confirmed',
      'remote monitoring is offline',
      'do not want to overstate',
      'dont want to overstate',
      'before i confirm',
      'before confirming',
      'routine on site activity',
      'rather than a confirmed problem',
      'security is already on site',
    ]);
    if (!answersClearly || genericPromiseReply) {
      return true;
    }
  }
  if (remoteMonitoringOffline && restorationAsk) {
    final answersRestoration = telegramAiContainsAny(normalizedReply, const [
      'do not have a confirmed time',
      'dont have a confirmed time',
      'no confirmed time',
      'remote monitoring is offline',
      'monitoring path is restored',
      'remote monitoring is restored',
      'back online',
      'restoration time',
    ]);
    if (!answersRestoration || genericPromiseReply) {
      return true;
    }
  }
  final recentCommunityReportVisible = telegramAiContainsAny(joinedContext, const [
    'community reports',
    'suspicious vehicle scouting',
    'latest confirmed activity was',
    'latest confirmed report was',
  ]);
  final noLiveVisualConfirmation = telegramAiContainsAny(joinedContext, const [
    'do not have live visual confirmation',
    'grounding this on the current operational picture rather than a live camera check',
  ]);
  if (reassuranceClarifierAsk &&
      recentCommunityReportVisible &&
      (noOpenIncident || noLiveVisualConfirmation)) {
    final answersCommunityClarifier = telegramAiContainsAny(normalizedReply, const [
      'not confirmed visually',
      'not confirmed yet',
      'latest logged report',
      'not sitting as an open incident',
      'do not have live visual confirmation',
      'manual follow up',
      'manual follow-up',
    ]);
    if (!answersCommunityClarifier ||
        genericPromiseReply ||
        telegramAiContainsAny(normalizedReply, const [
          'security on site',
          'secure right now',
          'camera check',
          'reviewing recent community reports',
        ])) {
      return true;
    }
  }
  if (operationalPictureClarifierAsk) {
    final explainsOperationalPicture = telegramAiContainsAny(normalizedReply, const [
      'latest logged report',
      'incident status',
      'rather than a live camera view',
      'suspicious vehicle report',
      'do not have live visual confirmation',
    ]);
    if (!explainsOperationalPicture ||
        telegramAiContainsAny(normalizedReply, const [
          'reviewing recent community reports',
          'we are checking',
        ])) {
      return true;
    }
  }
  if (cameraConnectionAsk && remoteMonitoringOffline) {
    final answersCameraConnection = telegramAiContainsAny(normalizedReply, const [
      'monitoring connection is offline',
      'live camera confirmation',
      'live visual confirmation',
      'connection is restored',
      'cannot say the connection is restored',
      'not confirmed yet',
      'on site fix',
      'camera connection',
    ]);
    if (!answersCameraConnection ||
        telegramAiContainsAny(normalizedReply, const [
          'community reports',
          'latest verified activity near camera',
          'current operational picture',
          'not sitting as an open incident',
        ])) {
      return true;
    }
  }
  final genericStatusFollowUp = _isGenericStatusFollowUp(normalizedMessage);
  final cameraStatusFollowUp =
      genericStatusFollowUp &&
      cameraHealthFactPacket != null &&
      _hasRecentCameraStatusContext(joinedContext);
  final currentSiteViewAsk = asksForTelegramClientBroadStatusOrCurrentSiteView(
    normalizedMessage,
  );
  final semanticMovementIdentificationAsk =
      _asksForSemanticMovementIdentification(
        '$normalizedMessage\n$normalizedClientAsk',
      );
  final imageSendWhyAsk = _asksWhyImageCannotBeSent(normalizedMessage);
  final recentUnusableCurrentImage = _recentThreadShowsUnusableCurrentImage(
    recentConversationTurns,
  );
  final recentDownCameraLabel = _recentThreadDownCameraLabel(
    recentConversationTurns,
  );
  final recentRecordedEventVisuals =
      _recentThreadMentionsRecordedEventVisuals(recentConversationTurns) ||
      (normalizedMessage.contains('hikconnect') &&
          normalizedMessage.contains('visual'));
  if (cameraStatusFollowUp) {
    final answersPacketStatus =
        cameraHealthFactPacket.status == ClientCameraHealthStatus.live
        ? telegramAiContainsAny(normalizedReply, const [
            'visual confirmation',
            'live camera access',
            'live visual access',
            'last successful visual confirmation',
          ])
        : telegramAiContainsAny(normalizedReply, const [
            'currently unavailable',
            'currently limited',
            'local camera bridge',
            'live camera access',
            'not confirmed yet',
          ]);
    final addsUnverifiedRestorationWork = telegramAiContainsAny(normalizedReply, const [
      'we are working on restoring',
      'we are working to restore',
      'working to restore the connection',
      'working to restore the bridge',
      'working on restoring the connection',
      'working on restoring the bridge',
      'monitoring the situation',
      'as soon as the bridge is restored',
      'as soon as the connection is restored',
    ]);
    final wronglyClaimsBridgeOffline =
        cameraHealthFactPacket.status == ClientCameraHealthStatus.live &&
        telegramAiContainsAny(normalizedReply, const [
          'bridge is offline',
          'local camera bridge is offline',
          'currently unavailable because the local camera bridge is offline',
        ]);
    if (!answersPacketStatus ||
        addsUnverifiedRestorationWork ||
        wronglyClaimsBridgeOffline) {
      return true;
    }
  }
  final cameraHealthReassuranceAsk =
      reassuranceClarifierAsk &&
      cameraHealthFactPacket != null &&
      cameraHealthFactPacket.status != ClientCameraHealthStatus.live;
  if (cameraHealthReassuranceAsk) {
    final answersCameraConstrainedReassurance =
        telegramAiContainsAny(normalizedReply, const [
          'not confirmed yet',
          'do not have live visual confirmation',
          'live camera access',
          'currently unavailable',
          'currently limited',
        ]);
    final addsUnverifiedRestorationWork = telegramAiContainsAny(normalizedReply, const [
      'we are working on restoring',
      'we are working to restore',
      'working to restore the connection',
      'working to restore the bridge',
      'working on restoring the connection',
      'working on restoring the bridge',
      'monitoring the situation',
    ]);
    if (!answersCameraConstrainedReassurance || addsUnverifiedRestorationWork) {
      return true;
    }
  }
  final comfortMonitoringAsk = _asksComfortOrMonitoringSupport(
    normalizedMessage,
  );
  final overnightAlertAsk = _asksOvernightAlertingSupport(normalizedMessage);
  final baselineSweepAsk = _asksForBaselineSweep(normalizedMessage);
  final baselineSweepStatusAsk = _asksAboutBaselineSweepStatus(
    normalizedMessage,
    recentConversationTurns,
  );
  final baselineSweepEtaAsk = _asksAboutBaselineSweepEta(
    normalizedMessage,
    recentConversationTurns,
  );
  final wholeSiteBreachReviewAsk = _asksForWholeSiteBreachReview(
    normalizedMessage,
    recentConversationTurns,
  );
  final wholeSiteBreachReviewStatusAsk = _asksAboutWholeSiteBreachReviewStatus(
    normalizedMessage,
    recentConversationTurns,
  );
  final wholeSiteBreachReviewEtaAsk = _asksAboutWholeSiteBreachReviewEta(
    normalizedMessage,
    recentConversationTurns,
  );
  final historicalAlarmReviewAsk = _asksForHistoricalAlarmReview(
    normalizedMessage,
    recentConversationTurns,
  );
  final historicalAlarmReviewStatusAsk = _asksAboutHistoricalAlarmReviewStatus(
    normalizedMessage,
    recentConversationTurns,
  );
  final historicalAlarmReviewEscalationAsk =
      _asksToEscalateHistoricalAlarmReview(
        normalizedMessage,
        recentConversationTurns,
      );
  final liveCameraReassuranceAsk =
      cameraHealthFactPacket != null &&
      cameraHealthFactPacket.status == ClientCameraHealthStatus.live &&
      (reassuranceClarifierAsk || comfortMonitoringAsk);
  if (overnightAlertAsk) {
    final answersGroundedAlerting = telegramAiContainsAny(normalizedReply, const [
      'confirmed alert',
      'message you here',
      'alert you here',
      'notify you here',
    ]);
    final overpromisesAlerting = telegramAiContainsAny(normalizedReply, const [
      'if something happens while youre asleep',
      'if something happens while you are asleep',
      'we will alert you right away',
      'next confirmed camera check',
    ]);
    if (!answersGroundedAlerting || overpromisesAlerting) {
      return true;
    }
  }
  if (baselineSweepAsk) {
    final answersBaselineSweep = telegramAiContainsAny(normalizedReply, const [
      'quick camera check',
      'confirmed result',
      'baseline normal',
    ]);
    final inventsSweepProgress = telegramAiContainsAny(normalizedReply, const [
      'im checking the baseline now',
      'i am checking the baseline now',
      'checking the baseline now',
      'using the local recorder bridge',
      'i am checking now',
      'im checking now',
    ]);
    if (!answersBaselineSweep || inventsSweepProgress) {
      return true;
    }
  }
  if (baselineSweepStatusAsk) {
    final answersBaselineStatus = telegramAiContainsAny(normalizedReply, const [
      'not yet confirmed',
      'do not have a baseline result',
      'dont have a baseline result',
    ]);
    final inventsSweepProgress = telegramAiContainsAny(normalizedReply, const [
      'im checking the baseline now',
      'i am checking the baseline now',
      'checking the baseline now',
      'using the local recorder bridge',
      'i am checking now',
      'im checking now',
    ]);
    if (!answersBaselineStatus || inventsSweepProgress) {
      return true;
    }
  }
  if (baselineSweepEtaAsk) {
    final answersBaselineEta = telegramAiContainsAny(normalizedReply, const [
      'few minutes',
      'confirmed timing',
      'send the result here once it is confirmed',
      'send the result here once its confirmed',
    ]);
    final inventsSweepProgress = telegramAiContainsAny(normalizedReply, const [
      'im checking the baseline now',
      'i am checking the baseline now',
      'checking the baseline now',
      'using the local recorder bridge',
      'i am checking now',
      'im checking now',
    ]);
    if (!answersBaselineEta || inventsSweepProgress) {
      return true;
    }
  }
  if (wholeSiteBreachReviewAsk) {
    final answersWholeSiteReview = telegramAiContainsAny(normalizedReply, const [
      'review the site signals',
      'confirmed result here',
      'full site',
      'full-site',
    ]);
    final inventsWholeSiteProgress = telegramAiContainsAny(normalizedReply, const [
      'we are reviewing all areas now',
      'reviewing all areas now',
      'checking every area now',
      'checking all areas now',
      'signs of breach',
      'following the alarm at',
      'i am checking now',
      'im checking now',
    ]);
    if (!answersWholeSiteReview || inventsWholeSiteProgress) {
      return true;
    }
  }
  if (wholeSiteBreachReviewStatusAsk) {
    final answersWholeSiteStatus = telegramAiContainsAny(normalizedReply, const [
      'not yet confirmed',
      'full-site breach result',
      'full site breach result',
    ]);
    final inventsWholeSiteProgress = telegramAiContainsAny(normalizedReply, const [
      'we are reviewing all areas now',
      'reviewing all areas now',
      'checking every area now',
      'checking all areas now',
      'signs of breach',
      'following the alarm at',
      'i am checking now',
      'im checking now',
    ]);
    if (!answersWholeSiteStatus || inventsWholeSiteProgress) {
      return true;
    }
  }
  if (wholeSiteBreachReviewEtaAsk) {
    final answersWholeSiteEta = telegramAiContainsAny(normalizedReply, const [
      'confirmed timing',
      'send the result here once it is confirmed',
      'send the result here once its confirmed',
    ]);
    final inventsWholeSiteProgress = telegramAiContainsAny(normalizedReply, const [
      'we are reviewing all areas now',
      'reviewing all areas now',
      'checking every area now',
      'checking all areas now',
      'signs of breach',
      'following the alarm at',
      'i am checking now',
      'im checking now',
    ]);
    if (!answersWholeSiteEta || inventsWholeSiteProgress) {
      return true;
    }
  }
  if (historicalAlarmReviewAsk) {
    final answersHistoricalReview = telegramAiContainsAny(normalizedReply, const [
      'asking about the 4am window',
      'historical review result',
      'not the current site status',
    ]);
    final inventsHistoricalProgress = telegramAiContainsAny(normalizedReply, const [
      'reviewing all outdoor cameras',
      'reviewing the perimeter now',
      'continue checking',
      'current visual confirmation through the local recorder bridge',
      'no live stream access to review the 4am alarm directly',
      'latest confirmed activity near the perimeter',
      'latest verified activity near perimeter',
    ]);
    if (!answersHistoricalReview || inventsHistoricalProgress) {
      return true;
    }
  }
  if (historicalAlarmReviewStatusAsk) {
    final answersHistoricalStatus = telegramAiContainsAny(normalizedReply, const [
      'not yet confirmed',
      'historical review result',
    ]);
    final inventsHistoricalProgress = telegramAiContainsAny(normalizedReply, const [
      'reviewing all outdoor cameras',
      'reviewing the perimeter now',
      'continue checking',
      'latest confirmed activity near the perimeter',
      'latest verified activity near perimeter',
    ]);
    if (!answersHistoricalStatus || inventsHistoricalProgress) {
      return true;
    }
  }
  if (historicalAlarmReviewEscalationAsk) {
    final answersHistoricalEscalation = telegramAiContainsAny(normalizedReply, const [
      'manual control review',
      'historical review result',
      '4am alarm window',
    ]);
    final inventsHistoricalProgress = telegramAiContainsAny(normalizedReply, const [
      'continue checking',
      'current visual confirmation through the local recorder bridge',
      'no live stream access to review the 4am alarm directly',
      'latest confirmed activity near the perimeter',
      'latest verified activity near perimeter',
    ]);
    if (!answersHistoricalEscalation || inventsHistoricalProgress) {
      return true;
    }
  }
  if (liveCameraReassuranceAsk) {
    final answersLiveCameraReassurance =
        telegramAiContainsAny(normalizedReply, const [
          'visual confirmation',
          'live camera access',
          'some visual coverage',
          'some visual confirmation',
        ]) &&
        telegramAiContainsAny(normalizedReply, const [
          'not confirmed yet',
          'do not want to overstate',
          'dont want to overstate',
          'do not want to overpromise',
          'dont want to overpromise',
          'will keep monitoring',
          'update you here',
        ]);
    final overclaimsSafety = telegramAiContainsAny(normalizedReply, const [
      'everything is stable',
      'stable at the moment',
      'stable right now',
      'safe right now',
      'you can rest easy',
      'rest easy',
      'sleep peacefully',
      'sleep easy',
      'monitoring closely',
      'closely monitoring',
      'staying close on this',
      'covering other cameras',
      'continuous visual watch is active on',
    ]);
    final inventsCoverageCount = _containsCameraCoverageCountClaim(
      normalizedReply,
    );
    final ignoresKnownCameraDown =
        recentDownCameraLabel != null &&
        !telegramAiContainsAny(normalizedReply, const [
          'partial camera coverage',
          'partial coverage',
          'some visual confirmation',
          'do not want to overstate',
          'camera 11 is down',
        ]);
    if (!answersLiveCameraReassurance ||
        overclaimsSafety ||
        inventsCoverageCount ||
        ignoresKnownCameraDown) {
      return true;
    }
  }
  if (currentSiteViewAsk && cameraHealthFactPacket != null) {
    final effectiveIssueStatus = _effectiveLiveSiteIssueStatus(
      cameraHealthFactPacket,
    );
    final answersCurrentSiteViewBoundary = telegramAiContainsAny(normalizedReply, const [
      'i am not seeing active movement on site',
      'i do not have confirmed live activity on site',
      'recent activity was picked up on site',
      'nothing in the current signals confirms an issue on site',
      'nothing here confirms an issue on site',
      'cannot verify the whole site visually at this moment',
      'do not have full remote visibility',
      'current signals i can see right now',
    ]);
    final driftsToCameraOnlyReassurance =
        telegramAiContainsAny(normalizedReply, const [
          'live camera visibility at',
          'live camera access at',
          'do not have live visual confirmation right now',
          'latest confirmed camera check',
        ]) &&
        !answersCurrentSiteViewBoundary;
    final wronglyClaimsBridgeOffline =
        cameraHealthFactPacket.status == ClientCameraHealthStatus.live &&
        telegramAiContainsAny(normalizedReply, const [
          'bridge is offline',
          'local camera bridge is offline',
          'currently unavailable because the local camera bridge is offline',
        ]);
    if (wronglyClaimsBridgeOffline) {
      return true;
    }
    if (effectiveIssueStatus == ClientLiveSiteIssueStatus.activeSignals ||
        effectiveIssueStatus == ClientLiveSiteIssueStatus.recentSignals) {
      final answersLiveSiteState = telegramAiContainsAny(normalizedReply, const [
        'i am seeing live activity around',
        'i am seeing recent activity',
        'recent activity was picked up on site',
        'nothing in the current signals confirms a threat right now',
        'site is not clear from current signals alone',
      ]);
      final overstatesStability = telegramAiContainsAny(normalizedReply, const [
        'everything on site is stable',
        'everything is stable',
        'site is stable',
        'stable right now',
        'stable at the moment',
        'all clear',
        'site is clear',
      ]);
      if (!answersLiveSiteState || overstatesStability) {
        return true;
      }
    }
    if (effectiveIssueStatus != ClientLiveSiteIssueStatus.activeSignals &&
        effectiveIssueStatus != ClientLiveSiteIssueStatus.recentSignals &&
        !recentUnusableCurrentImage &&
        recentDownCameraLabel == null &&
        (!answersCurrentSiteViewBoundary || driftsToCameraOnlyReassurance)) {
      return true;
    }
    if (recentUnusableCurrentImage) {
      final answersUnusableCurrentView = telegramAiContainsAny(normalizedReply, const [
        'usable current image',
        'do not have a usable current image',
        'do not want to overstate what is visible',
      ]);
      if (!answersUnusableCurrentView) {
        return true;
      }
    }
    if (recentDownCameraLabel != null) {
      final answersPartialCoverage = telegramAiContainsAny(normalizedReply, const [
        'camera 11 is down',
        'partial camera coverage',
        'partial coverage',
        'some visual coverage',
        'some visual confirmation',
        'do not want to overstate the full picture',
      ]);
      if (!answersPartialCoverage ||
          _containsCameraCoverageCountClaim(normalizedReply)) {
        return true;
      }
    }
  }
  if (semanticMovementIdentificationAsk && cameraHealthFactPacket != null) {
    final answersSemanticMovement = telegramAiContainsAny(normalizedReply, const [
      'confirmed person or vehicle activity',
      'do not have confirmed person or vehicle activity',
      'do not yet have a confirmed person or vehicle identification',
      'recent person activity',
      'recent vehicle activity',
      'live activity around',
    ]);
    final driftsToSingleFrameOrOutage = telegramAiContainsAny(normalizedReply, const [
      'current frame alone',
      'single image',
      'camera bridge is offline',
      'local camera bridge is offline',
      'cannot confirm movement visually right now',
    ]);
    if (!answersSemanticMovement || driftsToSingleFrameOrOutage) {
      return true;
    }
  }
  if (imageSendWhyAsk && recentRecordedEventVisuals) {
    final answersImageLimit = telegramAiContainsAny(normalizedReply, const [
      'recorded event visuals were logged',
      'usable exported image',
      'usable event image',
      'send here every time',
      'send here',
    ]);
    final wronglyClaimsBridgeOffline =
        cameraHealthFactPacket?.status == ClientCameraHealthStatus.live &&
        telegramAiContainsAny(normalizedReply, const [
          'bridge is offline',
          'local camera bridge is offline',
        ]);
    if (!answersImageLimit || wronglyClaimsBridgeOffline) {
      return true;
    }
  }
  final currentFrameMovementAsk =
      _asksForCurrentFrameMovementCheck(normalizedMessage) ||
      _asksForCurrentFramePersonConfirmation(normalizedMessage);
  final missedMovementDetectionChallenge = _challengesMissedMovementDetection(
    normalizedMessage,
    recentConversationTurns,
  );
  final currentFrameContext =
      (currentFrameMovementAsk || missedMovementDetectionChallenge) &&
      (_hasCurrentFrameConversationContext(
            joinedContext,
            cameraHealthFactPacket: cameraHealthFactPacket,
          ) ||
          _hasRecentMotionTelemetryContext(joinedContext));
  if (currentFrameContext) {
    final hasMotionTelemetry = _hasRecentMotionTelemetryContext(joinedContext);
    final answersCurrentFrameConservatively = hasMotionTelemetry
        ? telegramAiContainsAny(normalizedReply, const [
            'recent motion alerts',
            'recent motion alerts on camera',
            'it would be wrong to say nothing was picked up',
            'current frame alone',
            'single image',
            'who or what triggered those alerts',
            'whether that was a person',
          ])
        : telegramAiContainsAny(normalizedReply, const [
            'not confirmed from the current frame alone',
            'cannot confirm movement from a single image',
            'cannot confirm movement from a single frame',
            'cannot confirm a person',
            'single image',
            'single frame',
          ]);
    final makesCategoricalMovementClaim = telegramAiContainsAny(normalizedReply, const [
      'no movement is currently detected',
      'movement is currently detected',
      'no movement currently detected',
      'movement currently detected',
      'no movement in the backyard',
      'movement in the backyard',
      'next movement update',
      'movement update',
      'no confirmed movement was detected',
      'nothing was picked up',
    ]);
    if (!answersCurrentFrameConservatively || makesCategoricalMovementClaim) {
      return true;
    }
  }
  if (genericStatusFollowUp && !fieldTelemetryCountChallenge) {
    final repeatsTelemetryCountClarifier = telegramAiContainsAny(normalizedReply, const [
      'the count you see reflects telemetry signals',
      'telemetry signals dont always match',
      'telemetry signals do not always match',
      'not 19 people physically on site',
      'people physically on site',
    ]);
    if (repeatsTelemetryCountClarifier) {
      return true;
    }
  }
  if (reassuranceClarifierAsk && telemetrySummaryVisible && noOpenIncident) {
    final answersTelemetryClarifier = telegramAiContainsAny(normalizedReply, const [
      'not confirmed yet',
      'latest onyx telemetry shows',
      'nothing is currently sitting as an open incident',
      'do not have live visual confirmation',
      'manual follow up',
      'manual follow-up',
    ]);
    if (!answersTelemetryClarifier ||
        genericPromiseReply ||
        (!explicitOnSitePresence &&
            telegramAiContainsAny(normalizedReply, const [
              'security on site',
              'security is on site',
              'already on site',
            ])) ||
        (!explicitLiveCameraAccess &&
            telegramAiContainsAny(normalizedReply, const [
              'checking the cameras regularly',
              'checking cameras regularly',
              'camera checks regularly',
              'regular camera checks',
            ]))) {
      return true;
    }
  }
  if (reassuranceClarifierAsk && telemetrySummaryVisible) {
    final answersTelemetryClarifier = telegramAiContainsAny(normalizedReply, const [
      'not confirmed yet',
      'latest onyx telemetry shows',
      'do not have live visual confirmation',
      'manual follow up',
      'manual follow-up',
    ]);
    if (!answersTelemetryClarifier ||
        genericPromiseReply ||
        telegramAiContainsAny(normalizedReply, const [
          'security on site',
          'security is on site',
          'secure right now',
          'camera check',
          'checking the cameras regularly',
        ])) {
      return true;
    }
  }
  if (cameraReassuranceAsk) {
    final answersCameraClarifier = telegramAiContainsAny(normalizedReply, const [
      'do not have live camera confirmation',
      'do not have a live camera check',
      'cannot call it all clear',
      'cant call it all clear',
      'manual follow-up',
      'manual follow up',
      'does not show an open incident',
    ]);
    if (!answersCameraClarifier ||
        telegramAiContainsAny(normalizedReply, const [
          'latest verified activity near camera',
          'camera was community',
          'checking the cameras regularly',
          'security is on site',
        ])) {
      return true;
    }
  }
  if (camerasDownCorrection) {
    final acknowledgesCameraOutage = telegramAiContainsAny(normalizedReply, const [
      'your cameras are down',
      'cameras are down',
      'do not have live visual confirmation',
      'do not have live camera confirmation',
      'verify the current position manually',
      'manual',
    ]);
    if (!acknowledgesCameraOutage ||
        telegramAiContainsAny(normalizedReply, const [
          'camera check',
          'thorough camera check',
          'checking the cameras regularly',
          'live camera',
        ])) {
      return true;
    }
  }
  if (securityNotOnSiteCorrection) {
    final acknowledgesPositionCorrection = telegramAiContainsAny(normalizedReply, const [
      'will not call them on site',
      'security is not on site from your side',
      'verify the current response position',
      'current response position',
      'not call them on site',
    ]);
    if (!acknowledgesPositionCorrection ||
        telegramAiContainsAny(normalizedReply, const [
          'security is on site',
          'security is now on site',
          'already on site',
        ])) {
      return true;
    }
  }
  if (fieldTelemetryCountChallenge) {
    final explainsSignalsVsPresence = telegramAiContainsAny(normalizedReply, const [
      'telemetry signals',
      'recorded guard or response activity signals',
      'not 19 people physically on site',
      'not 19 people on site',
      'not 19 guards on site',
      'current position',
      'next confirmed step',
    ]);
    if (!explainsSignalsVsPresence || genericPromiseReply) {
      return true;
    }
  }
  if (telemetryDispatchClarifierAsk &&
      telemetrySummaryVisible &&
      !explicitOnSitePresence &&
      !explicitMovementConfirmation) {
    final explainsDispatchGrounding = telegramAiContainsAny(normalizedReply, const [
      'do not have a confirmed unit moving',
      'do not have a confirmed unit on site',
      'no confirmed active issue',
      'recorded onyx field telemetry',
      'not a confirmed active dispatch',
      'not a confirmed current unit on site',
      'current position',
    ]);
    if (!explainsDispatchGrounding ||
        genericPromiseReply ||
        telegramAiContainsAny(normalizedReply, const [
          'on their way',
          'moving toward the site',
          'moving to the site',
          'next on-site step',
          'security is on site',
          'already on site',
        ])) {
      return true;
    }
  }
  if (deliveryMode == TelegramAiDeliveryMode.approvalDraft &&
      normalizedOperatorDraft.isNotEmpty) {
    if (_approvalDraftReplyDriftsFromOperatorDraft(
      normalizedReply: normalizedReply,
      normalizedOperatorDraft: normalizedOperatorDraft,
      normalizedClientAsk: normalizedClientAsk,
    )) {
      return true;
    }
  }
  return false;
}

({String? clientAsk, String? operatorDraft}) _approvalDraftPromptContext(
  String messageText, {
  required TelegramAiDeliveryMode deliveryMode,
}) {
  if (deliveryMode != TelegramAiDeliveryMode.approvalDraft) {
    return (clientAsk: null, operatorDraft: null);
  }
  final clientAskMatch = RegExp(
    r'Client asked:\s*(.+?)\nCurrent operator draft:',
    dotAll: true,
  ).firstMatch(messageText);
  final operatorDraftMatch = RegExp(
    r'Current operator draft:\s*(.+?)(?:\nRefine the operator draft|\nPlease refine this operator draft|\Z)',
    dotAll: true,
  ).firstMatch(messageText);
  final inlineDraftMatch = RegExp(
    r'Please refine this operator draft into .*?:\s*(.+)$',
    dotAll: true,
  ).firstMatch(messageText);
  final clientAsk = clientAskMatch?.group(1)?.trim();
  final operatorDraft =
      operatorDraftMatch?.group(1)?.trim() ??
      inlineDraftMatch?.group(1)?.trim();
  return (
    clientAsk: clientAsk == null || clientAsk.isEmpty ? null : clientAsk,
    operatorDraft: operatorDraft == null || operatorDraft.isEmpty
        ? null
        : operatorDraft,
  );
}

String _fallbackPrimaryMessageText({
  required String messageText,
  required TelegramAiDeliveryMode deliveryMode,
}) {
  final approvalContext = _approvalDraftPromptContext(
    messageText,
    deliveryMode: deliveryMode,
  );
  return approvalContext.clientAsk ??
      approvalContext.operatorDraft ??
      messageText;
}

bool _approvalDraftReplyDriftsFromOperatorDraft({
  required String normalizedReply,
  required String normalizedOperatorDraft,
  required String normalizedClientAsk,
}) {
  final operatorMentionsRemote = telegramAiContainsAny(normalizedOperatorDraft, const [
    'remote monitoring',
    'remote watch',
    'live monitoring',
  ]);
  final replyMentionsMonitoring = telegramAiContainsAny(normalizedReply, const [
    'remote monitoring',
    'remote watch',
    'live monitoring',
  ]);
  final operatorMentionsUnit = telegramAiContainsAny(normalizedOperatorDraft, const [
    'send a unit',
    'unit over',
    'send a unit over',
  ]);
  final operatorMentionsSignalClarifier = telegramAiContainsAny(
    '$normalizedOperatorDraft\n$normalizedClientAsk',
    const [
      '19 guards',
      '19 guard',
      '19 response teams',
      'signals',
      'people on site',
    ],
  );
  final replyMentionsCamera = telegramAiContainsAny(normalizedReply, const [
    'camera',
    'cameras',
  ]);
  if (!telegramAiContainsAny('$normalizedOperatorDraft\n$normalizedClientAsk', const [
        'camera',
        'cameras',
      ]) &&
      replyMentionsCamera) {
    return true;
  }
  if (!operatorMentionsRemote &&
      !telegramAiContainsAny(normalizedClientAsk, const [
        'remote monitoring',
        'remote watch',
        'live monitoring',
      ]) &&
      replyMentionsMonitoring) {
    return true;
  }
  if (operatorMentionsUnit &&
      !telegramAiContainsAny(normalizedReply, const [
        'send a unit',
        'unit over',
        'unit',
      ])) {
    return true;
  }
  if (operatorMentionsRemote &&
      !telegramAiContainsAny(normalizedReply, const [
        'remote monitoring',
        'remote watch',
        'visual',
      ])) {
    return true;
  }
  if (operatorMentionsSignalClarifier &&
      !telegramAiContainsAny(normalizedReply, const [
        'telemetry',
        'signal',
        'signals',
        'people physically on site',
        'people on site',
        'security presence',
      ])) {
    return true;
  }
  return false;
}

String? _approvalDraftFallbackReply({
  required ({String? clientAsk, String? operatorDraft}) approvalContext,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required TelegramAiDeliveryMode deliveryMode,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required bool escalatedLane,
  required bool pressuredLane,
}) {
  final operatorDraft = approvalContext.operatorDraft?.trim();
  if (operatorDraft == null || operatorDraft.isEmpty) {
    return null;
  }
  final normalizedOperatorDraft = telegramAiNormalizeReplyHeuristicText(operatorDraft);
  final normalizedClientAsk = telegramAiNormalizeReplyHeuristicText(
    approvalContext.clientAsk ?? '',
  );
  final joinedContext = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final hasTelemetrySummary = telegramAiContainsAny(joinedContext, const [
    'site activity summary',
    'field telemetry',
    'latest field signal:',
    'guard or response-team activity signals were logged through onyx field telemetry',
    'guard or response-team activity signal was logged through onyx field telemetry',
  ]);
  final noOpenIncident = telegramAiContainsAny(joinedContext, const [
    'not sitting as an open incident',
    'open follow-ups: 0',
    'no client-facing action has been required',
  ]);
  final latestResponseArrival = telegramAiContainsAny(joinedContext, const [
    'field response unit arrived on site',
    'latest field signal: a field response unit arrived on site',
    'response arrival signal',
    'latest field signal: a response-arrival signal was logged through onyx field telemetry',
    'latest field signal: response arrival',
    'response arrival',
  ]);
  if (telegramAiContainsAny('$normalizedOperatorDraft\n$normalizedClientAsk', const [
    '19 guards',
    '19 guard',
    '19 response teams',
    'people on site',
  ])) {
    return 'That summary refers to recorded guard or response activity signals in ONYX telemetry, not 19 people physically on site. I can ask control to confirm the current position at ${scope.siteReference}, and ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.step, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, clientProfile: clientProfile, escalated: escalatedLane, compressed: pressuredLane)}';
  }
  if (telegramAiContainsAny(normalizedOperatorDraft, const [
    'remote monitoring',
    'remote watch',
    'live monitoring',
  ])) {
    final wantsUnitOffer = telegramAiContainsAny(normalizedOperatorDraft, const [
      'send a unit',
      'unit over',
      'send a unit over',
    ]);
    if (wantsUnitOffer) {
      return 'We do not have access to remote monitoring right now, so I cannot confirm visually from here. If everything looks fine on your side, please let us know, or tell us if you would like us to send a unit over.';
    }
  }
  if (telegramAiContainsAny('$normalizedOperatorDraft\n$normalizedClientAsk', const [
        'everything appears good',
        'everything is good',
        'everything good',
        'good for now',
      ]) &&
      hasTelemetrySummary) {
    final telemetryLead = latestResponseArrival
        ? 'The latest ONYX telemetry includes a response-arrival signal for ${scope.siteReference}'
        : 'The latest ONYX telemetry shows recent field activity at ${scope.siteReference}';
    final unitOffer = telegramAiContainsAny(
      '$normalizedOperatorDraft\n$normalizedClientAsk',
      const ['send a unit', 'unit over', 'assistance'],
    );
    final followUpSentence = unitOffer
        ? 'If you want, I can ask control to send a unit for a manual check.'
        : 'If you want a manual follow-up, message here and I will update you with the next confirmed step.';
    final noOpenIncidentSentence = noOpenIncident
        ? ' and nothing is currently sitting as an open incident'
        : '';
    return '$telemetryLead$noOpenIncidentSentence, but I do not have live visual confirmation right now. $followUpSentence';
  }
  return _ensureClientReplyCompleteness(
    _dedupeClientReplySentences(operatorDraft),
  );
}

String? _fieldTelemetryCountClarifierReply({
  required String normalizedMessage,
  required _TelegramAiScopeProfile scope,
  required List<String> recentConversationTurns,
  required TelegramAiDeliveryMode deliveryMode,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
  required bool escalatedLane,
  required bool pressuredLane,
}) {
  final challengesPresenceCount = _challengesTelemetryPresenceSummary(
    normalizedMessage,
  );
  if (!challengesPresenceCount) {
    return null;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  final hasTelemetrySummary = telegramAiContainsAny(joined, const [
    'guard or response-team activity signals were observed through onyx field telemetry',
    'guard or response team activity signals were observed through onyx field telemetry',
    'guard or response-team activity signals were logged through onyx field telemetry',
    'guard or response team activity signals were logged through onyx field telemetry',
    'site activity summary',
  ]);
  if (!hasTelemetrySummary) {
    return null;
  }
  return 'That count refers to recorded guard or response activity signals in ONYX telemetry, not 19 people physically on site. I can ask control to confirm the current position at ${scope.siteReference}, and ${_clientFollowUpClosing(recentConversationTurns, mode: _FollowUpMode.step, deliveryMode: deliveryMode, preferredReplyStyle: preferredReplyStyle, clientProfile: clientProfile, escalated: escalatedLane, compressed: pressuredLane)}';
}

_TelegramAiScopeProfile _scopeProfileFor({String? clientId, String? siteId}) {
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
        if (original.length <= 2 && RegExp(r'^[A-Z0-9]+$').hasMatch(original)) {
          return original;
        }
        if (entry.key > 0 && stopWords.contains(lower)) {
          return lower;
        }
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

enum _FollowUpMode { general, eta, step, movement, visual, onsite }

enum _ClientReplyIntent {
  general,
  worried,
  access,
  eta,
  movement,
  visual,
  status,
}

enum _ClientLaneStage { reassurance, escalated, responderOnSite, closure }

enum _PreferredReplyStyle { defaultStyle, shareStyle }

enum _ClientTonePack { standard, residential, enterprise }

enum _ClientProfile {
  standard,
  conciseUpdates,
  formalOperations,
  reassuranceForward,
  validationHeavy,
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
        return 'I will send the next confirmed step.';
      case _FollowUpMode.eta:
        return 'I will send the ETA when it is confirmed.';
      case _FollowUpMode.step:
        return 'I will send the next confirmed step.';
      case _FollowUpMode.movement:
        return 'I will send the next movement update when it is confirmed.';
      case _FollowUpMode.visual:
        return 'I will send the next camera update when it is confirmed.';
      case _FollowUpMode.onsite:
        return 'I will send the next on-site step when it is confirmed.';
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
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next on-site step here when it is confirmed.';
      }
      if (preferConcise ||
          compressed ||
          deliveryMode == TelegramAiDeliveryMode.approvalDraft ||
          escalated ||
          repeatedConfirmed ||
          repeatedKeepPosted ||
          repeatedMoment) {
        return 'I will update you here with the next on-site step.';
      }
      return 'I will update you here with the next on-site step.';
    case _FollowUpMode.eta:
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the ETA here when it is confirmed.';
      }
      if (preferConcise) {
        return 'I will update you here when it is confirmed.';
      }
      if (preferConcise ||
          compressed ||
          deliveryMode == TelegramAiDeliveryMode.approvalDraft ||
          escalated ||
          repeatedConfirmed ||
          repeatedKeepPosted) {
        return 'I will update you here when the ETA is confirmed.';
      }
      return 'I will update you here when the ETA is confirmed.';
    case _FollowUpMode.step:
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next confirmed step here when it is confirmed.';
      }
      if (preferConcise ||
          compressed ||
          deliveryMode == TelegramAiDeliveryMode.approvalDraft ||
          escalated ||
          repeatedConfirmed ||
          repeatedKeepPosted) {
        return 'I will update you here with the next confirmed step.';
      }
      return 'I will update you here with the next confirmed step.';
    case _FollowUpMode.movement:
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next movement here when it is confirmed.';
      }
      if (preferConcise ||
          compressed ||
          deliveryMode == TelegramAiDeliveryMode.approvalDraft ||
          escalated ||
          repeatedConfirmed ||
          repeatedKeepPosted ||
          repeatedMoment) {
        return 'I will update you here with the next movement update.';
      }
      return 'I will update you here with the next movement update.';
    case _FollowUpMode.visual:
      if (clientProfile == _ClientProfile.validationHeavy) {
        return 'I will update you here with the next confirmed camera check.';
      }
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next camera check here when it is confirmed.';
      }
      if (preferConcise ||
          compressed ||
          deliveryMode == TelegramAiDeliveryMode.approvalDraft ||
          escalated ||
          repeatedConfirmed ||
          repeatedKeepPosted ||
          repeatedMoment) {
        return 'I will update you here with the latest confirmed camera check.';
      }
      return 'I will update you here with the latest confirmed camera check.';
    case _FollowUpMode.general:
      if (preferredReplyStyle == _PreferredReplyStyle.shareStyle) {
        return 'I will share the next confirmed step here when it is confirmed.';
      }
      if (preferConcise ||
          compressed ||
          deliveryMode == TelegramAiDeliveryMode.approvalDraft ||
          escalated ||
          repeatedConfirmed ||
          repeatedKeepPosted ||
          repeatedMoment) {
        return 'I will update you here with the next confirmed step.';
      }
      return 'I will update you here with the next confirmed step.';
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
      return 'Security is on site at ${scope.siteReference}. I will send the next camera update when it is confirmed.';
    }
    return 'Security is on site at ${scope.siteReference}. I will send the next on-site step when it is confirmed.';
  }
  if (intent == _ClientReplyIntent.worried) {
    if (escalatedLane) {
      return 'High-priority alert escalated for ${scope.siteReference}. I will send the next confirmed step.';
    }
    return 'We are treating ${scope.siteReference} as live. I will send the next confirmed step.';
  }
  if (intent == _ClientReplyIntent.access) {
    return escalatedLane
        ? 'Access issue escalated for ${scope.siteReference}. I will send the next confirmed step.'
        : 'We are checking access for ${scope.siteReference}. I will send the next confirmed step.';
  }
  if (intent == _ClientReplyIntent.eta) {
    return escalatedLane
        ? 'Movement is escalated for ${scope.siteReference}. I will send the ETA when it is confirmed.'
        : 'We are checking the ETA for ${scope.siteReference}. I will send the ETA when it is confirmed.';
  }
  if (intent == _ClientReplyIntent.visual) {
    return escalatedLane
        ? 'Visual check escalated for ${scope.siteReference}. I will send the next camera update when it is confirmed.'
        : clientProfile == _ClientProfile.validationHeavy
        ? 'We are checking cameras and daylight at ${scope.siteReference}. I will send the next camera update when it is confirmed.'
        : 'We are checking cameras at ${scope.siteReference}. I will send the next camera update when it is confirmed.';
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'thank you',
    'thanks',
    'appreciate it',
  ])) {
    return 'You are welcome. I will update you if anything changes.';
  }
  if (escalatedLane) {
    return 'This is escalated for ${scope.siteReference}. I will send the next confirmed step.';
  }
  if (pressuredLane) {
    return 'We are checking ${scope.siteReference}. I will send the next confirmed step.';
  }
  return 'We are checking ${scope.siteReference}. I will send the next confirmed step.';
}

_ClientTonePack _clientTonePackFor(_TelegramAiScopeProfile scope) {
  final joined =
      '${scope.clientId} ${scope.siteId} ${scope.clientLabel} ${scope.siteLabel}'
          .toLowerCase();
  if (telegramAiContainsAny(joined, const [
    'residence',
    'residential',
    'estate',
    'villa',
    'home',
    'community',
    'vallee',
  ])) {
    return _ClientTonePack.residential;
  }
  if (telegramAiContainsAny(joined, const [
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
  ])) {
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
  if (clientProfile == _ClientProfile.formalOperations &&
      tonePack == _ClientTonePack.enterprise) {
    return pressured
        ? 'We are actively checking ${scope.siteReference} now and maintaining close review.'
        : 'We are actively checking ${scope.siteReference} now and maintaining close review.';
  }
  if (clientProfile == _ClientProfile.reassuranceForward) {
    return pressured
        ? 'You are not alone. We are treating this as live at ${scope.siteReference} now and staying close on this lane.'
        : 'You are not alone. We are treating this as live at ${scope.siteReference} and checking it now.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return pressured
          ? 'You are not alone. We are checking ${scope.siteReference} now.'
          : 'You are not alone. We are checking ${scope.siteReference} now.';
    case _ClientTonePack.enterprise:
      return pressured
          ? 'We are checking ${scope.siteReference} now and taking this seriously.'
          : 'We are checking ${scope.siteReference} now and taking this seriously.';
    case _ClientTonePack.standard:
      return pressured
          ? 'You are not alone. We are checking ${scope.siteReference} now.'
          : 'You are not alone. We are checking ${scope.siteReference} now.';
  }
}

String _statusLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
  _ClientProfile clientProfile = _ClientProfile.standard,
  bool pressured = false,
}) {
  if (clientProfile == _ClientProfile.formalOperations &&
      tonePack == _ClientTonePack.enterprise) {
    return pressured
        ? 'We are actively checking ${scope.siteReference} now.'
        : 'We are actively checking ${scope.siteReference} now.';
  }
  if (clientProfile == _ClientProfile.conciseUpdates) {
    return pressured
        ? 'We are checking ${scope.siteReference} now.'
        : 'We are checking ${scope.siteReference} now.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'We are checking ${scope.siteReference} now.';
    case _ClientTonePack.enterprise:
      return 'We are checking ${scope.siteReference} now.';
    case _ClientTonePack.standard:
      return 'We are checking ${scope.siteReference} now.';
  }
}

String _escalatedLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'This is already escalated for ${scope.siteReference}.';
    case _ClientTonePack.enterprise:
      return 'This is already escalated for ${scope.siteReference}.';
    case _ClientTonePack.standard:
      return 'This is already escalated for ${scope.siteReference}.';
  }
}

String _escalatedStatusLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'This is already escalated for ${scope.siteReference}.';
    case _ClientTonePack.enterprise:
      return 'This is already escalated for ${scope.siteReference}.';
    case _ClientTonePack.standard:
      return 'This is already escalated for ${scope.siteReference}.';
  }
}

String _thanksReplyForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
  _ClientProfile clientProfile = _ClientProfile.standard,
}) {
  if (clientProfile == _ClientProfile.formalOperations &&
      tonePack == _ClientTonePack.enterprise) {
    return 'You are welcome. I will keep you posted here if anything changes at ${scope.siteReference}.';
  }
  if (clientProfile == _ClientProfile.reassuranceForward) {
    return 'You are welcome. I will keep you posted here if anything changes at ${scope.siteReference}.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'You are welcome. I will keep you posted here if anything changes at ${scope.siteReference}.';
    case _ClientTonePack.enterprise:
      return 'You are welcome. I will keep you posted here if anything changes at ${scope.siteReference}.';
    case _ClientTonePack.standard:
      return 'You are welcome. I will keep you posted here if anything changes at ${scope.siteReference}.';
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
  if (joined.contains('formal-operations')) {
    return _ClientProfile.formalOperations;
  }
  return _ClientProfile.standard;
}

_ClientProfile _clientProfileFromSignalsAndTags({
  required List<String> clientProfileSignals,
  required List<String> preferredReplyStyleTags,
  required List<String> learnedReplyStyleTags,
}) {
  final explicit = _clientProfileFromSignals(clientProfileSignals);
  if (explicit != _ClientProfile.standard) {
    return explicit;
  }
  final joined = <String>[...preferredReplyStyleTags, ...learnedReplyStyleTags]
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return _ClientProfile.standard;
  }
  if (telegramAiContainsAny(joined, const [
    'formal',
    'operations',
    'operations-grade',
    'composed',
    'enterprise formal',
  ])) {
    return _ClientProfile.formalOperations;
  }
  if (telegramAiContainsAny(joined, const [
    'validation',
    'camera',
    'visual',
    'daylight',
  ])) {
    return _ClientProfile.validationHeavy;
  }
  if (telegramAiContainsAny(joined, const [
    'reassurance',
    'warm',
    'protective',
    'comfort',
    'calm',
  ])) {
    return _ClientProfile.reassuranceForward;
  }
  if (telegramAiContainsAny(joined, const [
    'crisp',
    'concise',
    'tight',
    'brief',
    'short',
    'eta',
  ])) {
    return _ClientProfile.conciseUpdates;
  }
  return _ClientProfile.standard;
}

String _accessLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
  _ClientProfile clientProfile = _ClientProfile.standard,
}) {
  if (clientProfile == _ClientProfile.formalOperations &&
      tonePack == _ClientTonePack.enterprise) {
    return 'We are actively checking access at ${scope.siteReference} now.';
  }
  if (clientProfile == _ClientProfile.conciseUpdates) {
    return tonePack == _ClientTonePack.enterprise
        ? 'We are checking access at ${scope.siteReference} now.'
        : 'We are checking access at ${scope.siteReference} now.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'We are checking access at ${scope.siteReference} now.';
    case _ClientTonePack.enterprise:
      return 'We are checking access at ${scope.siteReference} now.';
    case _ClientTonePack.standard:
      return 'We are checking access at ${scope.siteReference} now.';
  }
}

String _escalatedAccessLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'This is already escalated for ${scope.siteReference}.';
    case _ClientTonePack.enterprise:
      return 'This is already escalated for ${scope.siteReference}.';
    case _ClientTonePack.standard:
      return 'This is already escalated for ${scope.siteReference}.';
  }
}

String _visualLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
  _ClientProfile clientProfile = _ClientProfile.standard,
}) {
  if (clientProfile == _ClientProfile.validationHeavy) {
    return tonePack == _ClientTonePack.residential
        ? 'We are checking cameras and daylight around ${scope.siteReference} now.'
        : 'We are checking cameras and daylight at ${scope.siteReference} now.';
  }
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'We are checking cameras around ${scope.siteReference} now.';
    case _ClientTonePack.enterprise:
      return 'We are checking cameras at ${scope.siteReference} now.';
    case _ClientTonePack.standard:
      return 'We are checking cameras at ${scope.siteReference} now.';
  }
}

String _escalatedVisualLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'This is already escalated for ${scope.siteReference}.';
    case _ClientTonePack.enterprise:
      return 'This is already escalated for ${scope.siteReference}.';
    case _ClientTonePack.standard:
      return 'This is already escalated for ${scope.siteReference}.';
  }
}

String _onSiteAccessLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'Security is already on site at ${scope.siteReference}.';
    case _ClientTonePack.enterprise:
      return 'Security is already on site at ${scope.siteReference}.';
    case _ClientTonePack.standard:
      return 'Security is already on site at ${scope.siteReference}.';
  }
}

String _onSiteVisualLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'Security is already on site at ${scope.siteReference}.';
    case _ClientTonePack.enterprise:
      return 'Security is already on site at ${scope.siteReference}.';
    case _ClientTonePack.standard:
      return 'Security is already on site at ${scope.siteReference}.';
  }
}

String _onSiteWorriedLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'Security is already on site at ${scope.siteReference}.';
    case _ClientTonePack.enterprise:
      return 'Security is already on site at ${scope.siteReference}.';
    case _ClientTonePack.standard:
      return 'Security is already on site at ${scope.siteReference}.';
  }
}

String _onSiteStatusLeadForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'Security is already on site at ${scope.siteReference}.';
    case _ClientTonePack.enterprise:
      return 'Security is already on site at ${scope.siteReference}.';
    case _ClientTonePack.standard:
      return 'Security is already on site at ${scope.siteReference}.';
  }
}

String _closureReplyForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return '${scope.siteReference} is secure right now. If anything changes or feels off again, message here immediately and we will reopen this straight away.';
    case _ClientTonePack.enterprise:
      return '${scope.siteReference} is secure right now. If anything changes again, message here immediately and we will reopen the incident straight away.';
    case _ClientTonePack.standard:
      return '${scope.siteReference} is secure right now. If anything changes or feels off again, message here immediately and we will reopen this straight away.';
  }
}

String _closureAccessReplyForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return '${scope.siteReference} is secure right now. If access is still affected, tell me what is blocked and we will reopen this straight away.';
    case _ClientTonePack.enterprise:
      return '${scope.siteReference} is secure right now. If access is still affected, tell me what is blocked and we will reopen the incident straight away.';
    case _ClientTonePack.standard:
      return '${scope.siteReference} is secure right now. If access is still affected, tell me what is blocked and we will reopen this straight away.';
  }
}

String _closureThanksReplyForTonePack({
  required _TelegramAiScopeProfile scope,
  required _ClientTonePack tonePack,
}) {
  switch (tonePack) {
    case _ClientTonePack.residential:
      return 'You are welcome. ${scope.siteReference} is secure right now. If anything changes or feels off again, message here immediately.';
    case _ClientTonePack.enterprise:
      return 'You are welcome. ${scope.siteReference} is secure right now. If anything changes again, message here immediately.';
    case _ClientTonePack.standard:
      return 'You are welcome. ${scope.siteReference} is secure right now. If anything changes, message here immediately.';
  }
}

String _normalizeClientReplyDrift({
  required String text,
  required TelegramAiDeliveryMode deliveryMode,
  required _ClientLaneStage laneStage,
  required _PreferredReplyStyle preferredReplyStyle,
  required _ClientProfile clientProfile,
}) {
  var normalized = text.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  final followUpMode = _followUpModeFromReplyText(
    normalized,
    laneStage: laneStage,
  );
  final needsClosingNormalization =
      telegramAiContainsAny(normalized.toLowerCase(), const [
        'i will send',
        'i will share',
        'i will update you',
        'we will update you',
        'control will',
        'keep this lane updated',
        'keep you posted',
      ]);
  if (needsClosingNormalization) {
    final preferredClosing = _clientFollowUpClosing(
      const <String>[],
      mode: followUpMode,
      deliveryMode: deliveryMode,
      preferredReplyStyle: preferredReplyStyle,
      clientProfile: clientProfile,
    );
    normalized = _replaceClosingSentence(normalized, preferredClosing);
  }
  return normalized;
}

String _simplifyClientReplyLanguage(String text) {
  var normalized = text.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  normalized = normalized.replaceAll('access-control', 'access control');
  normalized = normalized.replaceAll('access control', 'access');
  normalized = normalized.replaceAll('actively checking', 'checking');
  normalized = normalized.replaceAll(
    'the latest operational position',
    'the site',
  );
  normalized = normalized.replaceAll('the latest position', 'the site');
  normalized = normalized.replaceAll('latest position', 'site');
  normalized = normalized.replaceAll('response movement', 'who is moving');
  normalized = normalized.replaceAll('Control will', 'I will');
  normalized = normalized.replaceAll('control will', 'I will');
  normalized = normalized.replaceAll(
    'as soon as control confirms it',
    'when it is confirmed',
  );
  normalized = normalized.replaceAll(
    'as soon as control has it',
    'when it is confirmed',
  );
  normalized = normalized.replaceAll('the moment control confirms', 'when');
  normalized = normalized.replaceAll(
    'the moment control has it',
    'when it is confirmed',
  );
  normalized = normalized.replaceAll('verified visual', 'camera check');
  normalized = normalized.replaceAll('visual update', 'camera update');
  normalized = normalized.replaceAll('latest camera view', 'cameras');
  normalized = normalized.replaceAll(
    'latest camera and daylight view',
    'cameras and daylight',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'We are on it at (.+?) and control is checking the latest position now\.',
    ),
    (match) => 'We are checking ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'We are checking access status for (.+?) now\.'),
    (match) => 'We are checking access at ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'We are checking access control status for (.+?) now\.'),
    (match) => 'We are checking access at ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'We are checking access-control status for (.+?) now\.'),
    (match) => 'We are checking access at ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'We are actively checking the latest position for (.+?) now\.'),
    (match) => 'We are checking ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'We are checking the latest position at (.+?) now\.'),
    (match) => 'We are checking ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'We are checking the latest camera view around (.+?) now\.'),
    (match) => 'We are checking cameras around ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'We are checking the latest camera view at (.+?) now\.'),
    (match) => 'We are checking cameras at ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'We are checking the latest camera and daylight view around (.+?) now\.',
    ),
    (match) =>
        'We are checking cameras and daylight around ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'We are checking the latest camera and daylight view for (.+?) now\.',
    ),
    (match) => 'We are checking cameras and daylight at ${match.group(1)} now.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'Security is already on site at (.+?)\. We are checking the latest on-site position there now\.',
    ),
    (match) => 'Security is already on site at ${match.group(1)}.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'Security is already on site at (.+?)\. We are checking the latest on-site position now\.',
    ),
    (match) => 'Security is already on site at ${match.group(1)}.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'Security is already on site at (.+?)\. We are checking the position there now\.',
    ),
    (match) => 'Security is already on site at ${match.group(1)}.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'Security is already on site at (.+?)\. We are checking the operational position there now\.',
    ),
    (match) => 'Security is already on site at ${match.group(1)}.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'This is already escalated with control for (.+?)\.'),
    (match) => 'This is already escalated for ${match.group(1)}.',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'The latest confirmed position is that (.+?) is secure\.'),
    (match) => '${match.group(1)} is secure right now.',
  );
  return normalized.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

_FollowUpMode _followUpModeFromReplyText(
  String text, {
  required _ClientLaneStage laneStage,
}) {
  final normalized = text.trim().toLowerCase();
  if (laneStage == _ClientLaneStage.responderOnSite &&
      telegramAiContainsAny(normalized, const ['on site', 'on-site'])) {
    return _FollowUpMode.onsite;
  }
  if (telegramAiContainsAny(normalized, const ['eta', 'live movement', 'arrival'])) {
    return _FollowUpMode.eta;
  }
  if (telegramAiContainsAny(normalized, const ['access status', 'gate', 'access'])) {
    return _FollowUpMode.step;
  }
  if (telegramAiContainsAny(normalized, const [
    'responder status',
    'movement',
    'armed response',
    'officer',
  ])) {
    return _FollowUpMode.movement;
  }
  if (telegramAiContainsAny(normalized, const [
    'camera',
    'visual',
    'cctv',
    'footage',
    'latest view',
  ])) {
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

String _dedupeClientReplySentences(String text) {
  final sentenceMatches = RegExp(
    r'[^.!?]+(?:[.!?]+|$)',
    multiLine: true,
  ).allMatches(text);
  final deduped = <String>[];
  String? previousNormalized;
  for (final match in sentenceMatches) {
    final sentence = match.group(0)?.trim() ?? '';
    if (sentence.isEmpty) {
      continue;
    }
    final normalized = telegramAiNormalizeReplyHeuristicText(sentence);
    if (normalized.isEmpty || normalized == previousNormalized) {
      continue;
    }
    deduped.add(sentence);
    previousNormalized = normalized;
  }
  if (deduped.isEmpty) {
    return text.trim();
  }
  return deduped.join(' ').trim();
}

String _ensureClientReplyCompleteness(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  if (RegExp(r"""[.!?]["']?$""").hasMatch(trimmed)) {
    return trimmed;
  }
  return '$trimmed.';
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

String? _learnedReplyExamplesSnippet(List<String> learnedReplyExamples) {
  final cleaned = learnedReplyExamples
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .take(3)
      .toList(growable: false);
  if (cleaned.isEmpty) {
    return null;
  }
  return cleaned.join('\n');
}

String? _replyStyleTagsSnippet(List<String> replyStyleTags) {
  final cleaned = <String>{};
  for (final value in replyStyleTags) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      continue;
    }
    cleaned.add(normalized);
    if (cleaned.length >= 3) {
      break;
    }
  }
  if (cleaned.isEmpty) {
    return null;
  }
  return cleaned.join(' • ');
}

List<String> _combinedReplyExamples({
  required List<String> preferredReplyExamples,
  required List<String> learnedReplyExamples,
}) {
  return <String>[...preferredReplyExamples, ...learnedReplyExamples];
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

_PreferredReplyStyle _preferredReplyStyleFromExamplesAndTags({
  required List<String> preferredReplyExamples,
  required List<String> preferredReplyStyleTags,
  required List<String> learnedReplyStyleTags,
}) {
  final explicit = _preferredReplyStyleFromExamples(preferredReplyExamples);
  if (explicit != _PreferredReplyStyle.defaultStyle) {
    return explicit;
  }
  final joined = <String>[...preferredReplyStyleTags, ...learnedReplyStyleTags]
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (telegramAiContainsAny(joined, const ['share', 'shared closing', 'share style'])) {
    return _PreferredReplyStyle.shareStyle;
  }
  return _PreferredReplyStyle.defaultStyle;
}

bool _isEscalatedLaneContext({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  if (telegramAiContainsAny(normalizedMessage, const [
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
  ])) {
    return true;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
    'escalated',
    'client escalated',
    'high-priority',
    'high priority',
    'alert received',
    'verification requested',
    'control room',
    'policy:high-risk',
  ]);
}

bool _isPressuredLaneContext({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  var pressureSignals = 0;
  if (telegramAiContainsAny(normalizedMessage, const [
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
  ])) {
    pressureSignals += 1;
  }
  for (final turn in recentConversationTurns.take(6)) {
    final normalizedTurn = turn.trim().toLowerCase();
    if (normalizedTurn.isEmpty) {
      continue;
    }
    if (telegramAiContainsAny(normalizedTurn, const [
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
    ])) {
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
      .map(telegramAiNormalizeReplyHeuristicText)
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (telegramAiContainsAny(joined, const [
    'incident resolved',
    'site secured',
    'resolved',
    'all clear',
    'closed out',
    'closure',
  ])) {
    return _ClientLaneStage.closure;
  }
  if (telegramAiContainsAny(joined, const [
    'responder on site',
    'security response activated',
    'partner dispatch sent',
    'response activated',
    'security is already on site',
    'security already on site',
    'response unit is on site',
    'guard is on site',
    'officer is on site',
  ])) {
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
  if (telegramAiContainsAny(normalizedMessage, const [
    'worried',
    'scared',
    'afraid',
    'panic',
    'panicking',
    'nervous',
    'unsafe',
    'can i sleep',
    'sleep peacefully',
    'rest easy',
    'help me',
    'please help',
  ])) {
    return _ClientReplyIntent.worried;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'gate',
    'access',
    'cant get in',
    'can\'t get in',
    'cant get out',
    'can\'t get out',
    'stuck outside',
    'stuck inside',
  ])) {
    return _ClientReplyIntent.access;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'eta',
    'arrival',
    'arrive',
    'how far',
    'how long',
  ])) {
    return _ClientReplyIntent.eta;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'guard',
    'officer',
    'response unit',
    'responder',
    'armed response',
    'police',
    'who is coming',
  ])) {
    return _ClientReplyIntent.movement;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'camera',
    'cctv',
    'video',
    'footage',
    'see on camera',
    'what do you see',
    'daylight',
  ])) {
    return _ClientReplyIntent.visual;
  }
  if (telegramAiContainsAny(normalizedMessage, const [
    'status',
    'update',
    'progress',
    'news',
    'happening',
  ])) {
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
  return telegramAiContainsAny(normalizedMessage, const [
    'still waiting',
    'anything yet',
    'any update',
    'update',
    'check now',
    'check again',
    'check again now',
    'check it now',
    'can you check now',
    'and now',
    'what now',
    'latest',
    'still',
    'yet',
    'still no',
  ]);
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
  if (telegramAiContainsAny(joined, const [
    'latest camera view',
    'confirmed visual update',
  ])) {
    return _ClientReplyIntent.visual;
  }
  if (telegramAiContainsAny(joined, const ['live movement', 'eta'])) {
    return _ClientReplyIntent.eta;
  }
  if (telegramAiContainsAny(joined, const ['access status', 'confirmed step'])) {
    return _ClientReplyIntent.access;
  }
  if (telegramAiContainsAny(joined, const ['responder status', 'movement update'])) {
    return _ClientReplyIntent.movement;
  }
  if (telegramAiContainsAny(joined, const [
    'treating this as live',
    'you are not alone',
  ])) {
    return _ClientReplyIntent.worried;
  }
  return _ClientReplyIntent.status;
}

bool _hasTelemetrySummaryContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'site activity summary',
    'field telemetry',
    'latest field signal:',
    'guard or response-team activity signals were logged through onyx field telemetry',
    'guard or response-team activity signal was logged through onyx field telemetry',
    'guard or response team activity signals were logged through onyx field telemetry',
    'guard or response team activity signal was logged through onyx field telemetry',
  ]);
}

bool _hasTelemetryResponseArrivalSignal(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'field response unit arrived on site',
    'latest field signal: a field response unit arrived on site',
    'response arrival signal',
    'latest field signal: a response-arrival signal was logged through onyx field telemetry',
    'latest field signal: response arrival',
  ]);
}

bool _hasExplicitCurrentOnSitePresence(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'responder on site',
    'security is already on site',
    'security already on site',
    'response unit is on site',
    'guard is on site',
    'officer is on site',
  ]);
}

bool _hasExplicitCurrentMovementConfirmation(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'partner dispatch sent',
    'security response activated',
    'response activated',
    'dispatch en route',
    'unit en route',
    'on the way',
    'eta confirmed',
  ]);
}

bool _asksWhyNoLiveCameraAccess(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'why cant you see my cameras',
    'why can you not see my cameras',
    'why cant you see the cameras',
    'why can you not see the cameras',
    'why cant you see cameras',
    'why can you not see cameras',
    'why cant you see my camera',
    'why can you not see my camera',
    'why cant we view live',
    'why can we not view live',
    'why cant we see live',
    'why can we not see live',
    'why cant we view live cameras',
    'why can we not view live cameras',
    'why cant we see live cameras',
    'why can we not see live cameras',
    'why cant we view the cameras live',
    'why can we not view the cameras live',
  ]);
}

bool _asksIfConnectionOrBridgeIsFixed(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'is the connection fixed',
    'is the camera connection fixed',
    'is the connection back',
    'are the cameras back',
    'is it fixed',
    'is it back up',
    'is monitoring back up',
    'is the bridge restored',
    'is the bridge back',
    'is the bridge fixed',
    'is the bridge online',
    'is the local camera bridge restored',
    'is the local camera bridge back',
  ]);
}

bool _assertsLiveVisualAccessState(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'live visual are active',
    'live visual is active',
    'live visuals are active',
    'live visuals is active',
    'live visual active',
    'live visuals active',
    'visual confirmation is active',
    'visual confirmation active',
    'live camera is active',
    'live cameras are active',
    'live camera active',
    'live cameras active',
    'cameras are online',
    'camera is online',
    'cameras online',
    'camera online',
    'cameras are not offline',
    'camera is not offline',
    'cameras arent offline',
    'camera isnt offline',
    'cameras are not down',
    'camera is not down',
    'cameras arent down',
    'camera isnt down',
    'cctv is online',
    'cctv online',
    'bridge is online',
    'bridge online',
    'bridge is not offline',
    'bridge isnt offline',
    'camera bridge is online',
    'local camera bridge is online',
    'camera bridge is not offline',
    'local camera bridge is not offline',
    'cameras are back',
    'camera is back',
  ]);
}

bool _asksHypotheticalEscalationCapability(String normalizedMessage) {
  final asksEscalationCapability = telegramAiContainsAny(normalizedMessage, const [
    'can you escalate',
    'could you escalate',
    'would you escalate',
    'will you escalate',
    'can onyx escalate',
  ]);
  final conditionalHelpAsk = telegramAiContainsAny(normalizedMessage, const [
    'if i need help',
    'if i need urgent help',
    'if i need assistance',
    'if something happens',
    'if there is a problem',
    'if theres a problem',
  ]);
  return asksEscalationCapability && conditionalHelpAsk;
}

bool _asksForCurrentSiteIssueCheck(String normalizedMessage) {
  return asksForTelegramClientCurrentSiteIssueCheck(normalizedMessage);
}

bool _asksForCurrentFrameMovementCheck(String normalizedMessage) {
  return asksForTelegramClientMovementCheck(normalizedMessage);
}

bool _asksForSemanticMovementIdentification(String normalizedMessage) {
  final asksMovement = telegramAiContainsAny(normalizedMessage, const [
    'any movement',
    'movement',
    'identify',
    'identifying',
    'detected',
    'detection',
    'see',
  ]);
  final asksSemanticObject = telegramAiContainsAny(normalizedMessage, const [
    'vehicle or human',
    'vehicles or humans',
    'vehicle or person',
    'person or vehicle',
    'persons or vehicles',
    'human or vehicle',
    'humans or vehicles',
    'vehicle or people',
    'people or vehicle',
    'vehicles or people',
    'person or human',
    'human or person',
    'human',
    'humans',
    'person',
    'persons',
    'people',
    'vehicle',
    'vehicles',
  ]);
  if (!asksSemanticObject) {
    return false;
  }
  return asksMovement ||
      telegramAiContainsAny(normalizedMessage, const [
        'what is moving',
        'who is moving',
        'what do you see',
        'what are you seeing',
      ]);
}

bool _asksForCurrentFramePersonConfirmation(String normalizedMessage) {
  final explicitSighting = telegramAiContainsAny(normalizedMessage, const [
    'i see someone',
    'i can see someone',
    'someone there',
    'person there',
  ]);
  final explicitConfirmation = telegramAiContainsAny(normalizedMessage, const [
    'can you confirm',
    'please confirm',
    'confirm that',
    'confirm this',
  ]);
  final referencesPerson = telegramAiContainsAny(normalizedMessage, const [
    'someone',
    'person',
  ]);
  final referencesArea = telegramAiContainsAny(normalizedMessage, const [
    'backyard',
    'back yard',
    'front yard',
    'frontyard',
    'driveway',
    'gate',
  ]);
  return ((explicitSighting || explicitConfirmation) &&
          referencesPerson &&
          (referencesArea || explicitSighting)) ||
      telegramAiContainsAny(normalizedMessage, const [
        'someone in backyard',
        'someone in the backyard',
        'person in backyard',
        'person in the backyard',
      ]);
}

bool _hasCurrentFrameConversationContext(
  String joinedContext, {
  required ClientCameraHealthFactPacket? cameraHealthFactPacket,
}) {
  if (cameraHealthFactPacket?.hasCurrentVisualConfirmation == true) {
    return true;
  }
  return telegramAiContainsAny(joinedContext, const [
    'current verified frame from',
    '[image] current verified frame from',
    'latest verified frame',
    'latest camera picture',
    'visual confirmation at',
  ]);
}

bool _hasRecentMotionTelemetryContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'motion detection alarm',
    'motion alarm',
    'recent motion alerts',
    'recent movement alerts',
    'detected movement on camera',
    'identified repeat movement activity on',
    'movement activity on camera',
  ]);
}

String _recentMotionTelemetryLeadLabel(String joinedContext) {
  final cameraMatch = RegExp(
    r'camera\s+(\d+)',
    caseSensitive: false,
  ).firstMatch(joinedContext);
  final cameraDigits = cameraMatch?.group(1) ?? '';
  if (cameraDigits.isNotEmpty) {
    return 'recent motion alerts on Camera $cameraDigits';
  }
  return 'recent motion alerts';
}

bool _challengesTelemetryPresenceSummary(String normalizedMessage) {
  final challengesExplicitCount = telegramAiContainsAny(normalizedMessage, const [
    'there isnt 19 guard',
    'there is not 19 guard',
    'there arent 19 guard',
    'there are not 19 guard',
    'not 19 guards',
    'not 19 response teams',
    '19 guards or response teams on site',
    '19 guard or response teams on site',
    'people on site',
  ]);
  final mentionsPresenceTarget =
      normalizedMessage.contains('guard') ||
      normalizedMessage.contains('response team') ||
      normalizedMessage.contains('people');
  final mentionsSiteOrPremises =
      normalizedMessage.contains('site') ||
      normalizedMessage.contains('there') ||
      normalizedMessage.contains('premis');
  final deniesPresence = telegramAiContainsAny(normalizedMessage, const [
    'there are no',
    'there is no',
    'there arent',
    'there are not',
    'there isnt',
    'no guards',
    'no guard',
    'no one',
    'nobody',
    'not on site',
    'not there',
  ]);
  return challengesExplicitCount ||
      (mentionsPresenceTarget && mentionsSiteOrPremises && deniesPresence);
}

bool _hasRecentPresenceVerificationContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'site activity summary',
    'field telemetry',
    'latest field signal',
    'response-arrival signal',
    'recorded onyx telemetry activity',
    'recorded onyx field telemetry',
    'recorded guard or response activity signals',
    'not confirmed guards physically on site',
    'not 19 people physically on site',
    'no guard is confirmed on site',
    'current response position',
    'verified position update',
    'there are no guards',
    'there is no guard',
    'no guards at',
    'no guards on',
    'security is not on site',
    'security not on site',
  ]);
}

bool _hasRecentContinuousVisualActivityContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'live visual change',
    'continuous visual watch',
    'active scene change',
    'scene change is being tracked',
    'i am seeing live activity around',
    'i am seeing activity around',
    'something active is happening there',
  ]);
}

bool _challengesMissedMovementDetection(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  final directChallenge = telegramAiContainsAny(normalizedMessage, const [
    'picked up nothing',
    'you picked up nothing',
    'detected nothing',
    'you detected nothing',
    'saw nothing',
    'you saw nothing',
    'nothing was picked up',
  ]);
  final walkedPastCameras =
      telegramAiContainsAny(normalizedMessage, const [
        'i just walked past',
        'i walked past',
        'walked past',
      ]) &&
      normalizedMessage.contains('camera');
  final cameraCountCorrection = RegExp(
    r'^(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+cameras?$',
  ).hasMatch(normalizedMessage);
  if (directChallenge || walkedPastCameras) {
    return true;
  }
  if (!cameraCountCorrection) {
    return false;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  return telegramAiContainsAny(joined, const [
    'picked up nothing',
    'you picked up nothing',
    'walked past',
  ]);
}

String? _currentFrameConfirmationAreaLabel(String normalizedMessage) {
  if (telegramAiContainsAny(normalizedMessage, const ['backyard', 'back yard'])) {
    return 'backyard';
  }
  if (telegramAiContainsAny(normalizedMessage, const ['front yard', 'frontyard'])) {
    return 'front yard';
  }
  if (normalizedMessage.contains('driveway')) {
    return 'driveway';
  }
  if (normalizedMessage.contains('gate')) {
    return 'gate area';
  }
  return null;
}

bool _isGenericStatusFollowUp(String normalizedMessage) {
  return asksForTelegramClientGenericStatusFollowUp(normalizedMessage) ||
      (normalizedMessage.split(RegExp(r'\s+')).length <= 4 &&
          telegramAiContainsAny(normalizedMessage, const ['status', 'anything new']));
}

bool _hasRecentCameraStatusContext(String joinedContext) {
  return telegramAiContainsAny(joinedContext, const [
    'live camera access',
    'live visual access',
    'live camera confirmation',
    'live visual confirmation',
    'visual confirmation at',
    'live camera visibility',
    'camera bridge',
    'local camera bridge',
    'temporary local recorder bridge',
    'remote monitoring',
    'remote watch',
    'monitoring connection',
    'monitoring path',
    'camera connection',
    'camera access',
    'cameras back',
    'bridge is offline',
    'bridge is not responding',
    'bridge offline',
  ]);
}

bool _recentThreadShowsUnusableCurrentImage(
  List<String> recentConversationTurns,
) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
    'do not have a usable current verified image',
    'do not have a usable current image',
    'could not attach the current frame',
    'do not have a current verified image to send right now',
  ]);
}

String? _recentThreadDownCameraLabel(List<String> recentConversationTurns) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return null;
  }
  final match = RegExp(
    r'camera\s+(\d+)\s+(?:(?:is|was)\s+)?(?:currently\s+)?(?:down|offline)',
  ).firstMatch(joined);
  final digits = match?.group(1) ?? '';
  if (digits.isEmpty) {
    return null;
  }
  return 'Camera $digits';
}

bool _recentThreadMentionsRecordedEventVisuals(
  List<String> recentConversationTurns,
) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
    'latest event image',
    'event image from camera',
    'motion detection alarm',
    'verification image has been retrieved',
    'recent event image',
    'with visuals',
    'hikconnect',
  ]);
}

bool _isBroadReassuranceAsk(String normalizedMessage) {
  return asksForTelegramClientBroadReassuranceCheck(normalizedMessage);
}

bool _asksComfortOrMonitoringSupport(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'can i sleep peacefully',
    'can i sleep',
    'can i rest easy',
    'can i rest',
    'will you monitor',
    'will you keep monitoring',
    'will you keep watch',
    'will you watch',
    'watch the site',
    'monitor the site',
    'keep monitoring',
    'keep watch',
  ]);
}

bool _asksForCurrentSiteView(String normalizedMessage) {
  return asksForTelegramClientCurrentSiteView(normalizedMessage);
}

bool _asksWhyImageCannotBeSent(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'why cant you send me one',
    'why cant you send one',
    'why cant you send me an image',
    'why cant you send me a picture',
    'why cant you send me a photo',
    'why cant you send it',
    'why cant you send one then',
    'why can t you send me one',
    'why can t you send one',
    'why cant we view live',
  ]);
}

bool _containsCameraCoverageCountClaim(String text) {
  return RegExp(r'\b\d+\s+(?:other\s+)?cameras?\b').hasMatch(text);
}

bool _asksOvernightAlertingSupport(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'if im asleep and something happens',
    'if i am asleep and something happens',
    'if something happens while im asleep',
    'if something happens while i am asleep',
    'will you alert me right',
    'will you alert me',
    'alert me right',
    'alert me if something happens',
    'wake me if something happens',
  ]);
}

bool _asksForBaselineSweep(String normalizedMessage) {
  return telegramAiContainsAny(normalizedMessage, const [
    'quick sweep',
    'do a quick sweep',
    'can you do a quick sweep',
    'baseline is normal',
    'baseline normal',
    'check the baseline',
    'see that the site is normal',
    'see that the sites baseline is normal',
    'quick baseline check',
  ]);
}

bool _asksAboutBaselineSweepStatus(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!_hasRecentBaselineSweepContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'did you check',
    'have you checked',
    'have you checked yet',
    'did you sweep',
    'did you do the sweep',
    'did you do a sweep',
    'did you do the check',
    'did you check yet',
  ]);
}

bool _asksAboutBaselineSweepEta(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!_hasRecentBaselineSweepContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'how long will you take',
    'how long will this take',
    'how long will it take',
    'how long',
    'when will you finish',
  ]);
}

bool _hasRecentBaselineSweepContext(List<String> recentConversationTurns) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
    'quick camera check',
    'quick sweep',
    'baseline result',
    'baseline normal',
    'checking the baseline',
  ]);
}

bool _asksForWholeSiteBreachReview(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  final asksToCheck = telegramAiContainsAny(normalizedMessage, const [
    'check every area',
    'check all areas',
    'review every area',
    'review all areas',
    'verify every area',
    'verify all areas',
    'check the whole site',
    'check the whole property',
    'check the entire site',
    'check the entire property',
  ]);
  if (!asksToCheck) {
    return false;
  }
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  return telegramAiContainsAny('$normalizedMessage\n$joined', const [
    'alarm',
    'breach',
    'what happened',
    '4am',
    '04 00',
    '04:00',
  ]);
}

bool _asksAboutWholeSiteBreachReviewStatus(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!_hasRecentWholeSiteBreachReviewContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'did you check',
    'did you check yet',
    'have you checked',
    'have you checked yet',
    'did you review it',
    'did you review the site',
    'any result yet',
  ]);
}

bool _asksAboutWholeSiteBreachReviewEta(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!_hasRecentWholeSiteBreachReviewContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'how long will you take',
    'how long will this take',
    'how long will it take',
    'how long',
    'when will you finish',
  ]);
}

bool _hasRecentWholeSiteBreachReviewContext(
  List<String> recentConversationTurns,
) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
        'check every area',
        'check all areas',
        'review the site signals',
        'full-site breach result',
        'full site breach result',
      ]) &&
      telegramAiContainsAny(joined, const ['alarm', 'breach', '4am', '04:00']);
}

bool _asksForHistoricalAlarmReview(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  final asksToReview = telegramAiContainsAny(normalizedMessage, const [
    'last night activity',
    'last nights activity',
    'check last night',
    'review last night',
    'check the 4am',
    'review the 4am',
    'around 4am',
    'while setup was live',
    'while the setup was live',
    'while setup live',
  ]);
  if (!asksToReview) {
    return false;
  }
  return _hasRecentHistoricalAlarmReviewContext(recentConversationTurns) ||
      telegramAiContainsAny(normalizedMessage, const [
        'alarm',
        'trigger',
        'perimeter',
        'outdoor camera',
        'outdoor cameras',
        '4am',
        '04:00',
      ]);
}

bool _asksAboutHistoricalAlarmReviewStatus(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!_hasRecentHistoricalAlarmReviewContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'did you check',
    'did you check yet',
    'have you checked',
    'have you checked yet',
    'did you review it',
    'did you review last night',
    'any result yet',
  ]);
}

bool _asksToEscalateHistoricalAlarmReview(
  String normalizedMessage,
  List<String> recentConversationTurns,
) {
  if (!_hasRecentHistoricalAlarmReviewContext(recentConversationTurns)) {
    return false;
  }
  return telegramAiContainsAny(normalizedMessage, const [
    'escalate',
    'escalate this',
    'manual review',
    'control review',
  ]);
}

bool _hasRecentHistoricalAlarmReviewContext(
  List<String> recentConversationTurns,
) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (joined.isEmpty) {
    return false;
  }
  return telegramAiContainsAny(joined, const [
    'alarm at around 4am',
    'alarm trigger at around 4am',
    'closest to 04:00',
    '4am window',
    'last night activity',
    'while setup was live',
  ]);
}

String _historicalAlarmReviewScopeLabel(List<String> recentConversationTurns) {
  final joined = recentConversationTurns
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (telegramAiContainsAny(joined, const ['outdoor camera', 'outdoor cameras'])) {
    if (telegramAiContainsAny(joined, const ['perimeter'])) {
      return 'the perimeter and outdoor cameras';
    }
    return 'the outdoor cameras';
  }
  if (telegramAiContainsAny(joined, const ['perimeter'])) {
    return 'the perimeter';
  }
  return 'that 4am window';
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
