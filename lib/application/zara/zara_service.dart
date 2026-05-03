import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'capability_registry.dart';
import 'llm_provider.dart';
import 'system_prompt.dart';
import 'tools/zara_tool.dart';
import 'tools/zara_tool_registry.dart';

/// Caller-neutral site context. Adapter-side code (e.g. Telegram) maps its
/// own context type into this at the boundary so ZaraService doesn't depend
/// on transport types.
class ZaraSiteContext {
  final DateTime observedAtUtc;
  final bool perimeterClear;
  final int humanCount;
  final int vehicleCount;
  final int animalCount;
  final int motionCount;
  final int activeAlertCount;
  final List<String> knownFaultChannels;
  final String contextSummary;

  const ZaraSiteContext({
    required this.observedAtUtc,
    required this.perimeterClear,
    required this.humanCount,
    required this.vehicleCount,
    required this.animalCount,
    required this.motionCount,
    required this.activeAlertCount,
    this.knownFaultChannels = const <String>[],
    required this.contextSummary,
  });
}

/// Coarse audience classification. Maps from TelegramAiAudience today; future
/// surfaces (web shell, voice gateway) map their own concepts in.
enum ZaraAudience { admin, client }

/// What Zara was asked to do.
class ZaraTurnRequest {
  final String userMessage;
  final ZaraAudience audience;
  final String? clientId;
  final String? siteId;
  final ZaraAllowanceTier allowanceTier;
  final Iterable<String> activeDataSources;
  final ZaraSiteContext? siteContext;

  const ZaraTurnRequest({
    required this.userMessage,
    required this.audience,
    this.clientId,
    this.siteId,
    required this.allowanceTier,
    this.activeDataSources = const <String>[],
    this.siteContext,
  });
}

/// Outcome shape for the current Zara transport contract.
enum ZaraDecision { delegated, refusedDataSource, fallback }

class ZaraTurnResult {
  final String text;
  final ZaraDecision decision;
  final String providerLabel;
  final String? capabilityKey;
  final String? internalReason;
  final bool usedFallback;

  const ZaraTurnResult({
    required this.text,
    required this.decision,
    required this.providerLabel,
    this.capabilityKey,
    this.internalReason,
    this.usedFallback = false,
  });
}

abstract class ZaraService {
  bool get isConfigured;
  Future<ZaraTurnResult> handleTurn(ZaraTurnRequest request);
}

class UnconfiguredZaraService implements ZaraService {
  const UnconfiguredZaraService();

  @override
  bool get isConfigured => false;

  @override
  Future<ZaraTurnResult> handleTurn(ZaraTurnRequest request) async {
    return const ZaraTurnResult(
      text: 'Message received. Monitoring continues.',
      decision: ZaraDecision.fallback,
      providerLabel: 'fallback',
      usedFallback: true,
    );
  }
}

const String _fallbackText = 'Message received. Monitoring continues.';
const String _fallbackProviderLabel = 'fallback';
const String _gatedProviderLabel = 'gated';

/// Shared v1 classifier for Zara-first Telegram phrasing.
///
/// This is intentionally narrow. It exists so transport layers can give Zara
/// first shot at the phrases we explicitly seeded, without duplicating the
/// phrase buckets in multiple places.
ZaraCapabilityDefinition? classifyZaraCapability(String userMessage) {
  final normalised = userMessage.trim().toLowerCase();
  if (normalised.isEmpty) return null;

  const incidentPhrases = <String>[
    'summarise the incident',
    'summarize the incident',
    'incident summary',
    'what happened with',
    'what happened at',
    'tell me about the incident',
    'walk me through the incident',
  ];
  if (incidentPhrases.any(normalised.contains)) {
    return zaraCapabilityByKey('incident_summary_reply');
  }

  const peakOccupancyPhrases = <String>[
    'peak occupancy',
    'highest count today',
    'most people today',
  ];
  if (peakOccupancyPhrases.any(normalised.contains)) {
    return zaraCapabilityByKey('peak_occupancy');
  }

  const statusPhrases = <String>[
    'all clear',
    'all good',
    'site status',
    'status check',
    'anything to report',
    "what's happening",
    'whats happening',
    'how are things',
    'how many on site',
    'how many on site right now',
    'how many people at once',
    "who's on site",
    'current occupancy',
  ];
  if (statusPhrases.any(normalised.contains)) {
    return zaraCapabilityByKey('monitoring_status_brief');
  }

  return null;
}

/// Concrete ZaraService backed by an injected LlmProvider.
///
/// Provider-agnostic by design: this class does not name Anthropic, OpenAI,
/// or Ollama. The injected LlmProvider is the only seam to the model layer.
///
/// v1 scope:
/// - Classifier recognises three capability keys (see classifyZaraCapability).
///   Unmatched messages return ZaraDecision.fallback.
/// - Capability access is infrastructure-gated only. Commercial allowance
///   tiers are carried through for future quota handling, not for access.
/// - LlmServiceLevel.primary only. No escalation routing.
/// - On provider failure, returns deterministic fallback. Does not improvise.
/// - request.audience and request.siteContext are unused in v1; reserved for
///   future prompt-builder expansion.
class ProviderBackedZaraService implements ZaraService {
  final LlmProvider llmProvider;
  final ZaraToolRegistry toolRegistry;

  static const int _maxToolIterations = 5;

  const ProviderBackedZaraService({
    required this.llmProvider,
    this.toolRegistry = emptyZaraToolRegistry,
  });

  @override
  bool get isConfigured => llmProvider.isConfigured;

  @override
  Future<ZaraTurnResult> handleTurn(ZaraTurnRequest request) async {
    if (!isConfigured) {
      developer.log(
        'provider not configured; returning deterministic fallback.',
        name: 'zara',
      );
      return _fallback(internalReason: 'llm provider not configured');
    }

    final capability = classifyZaraCapability(request.userMessage);
    if (capability == null) {
      developer.log(
        'no capability matched for inbound message; returning deterministic fallback.',
        name: 'zara',
      );
      return _fallback(internalReason: 'no capability matched');
    }

    final dataSourceOk = zaraCapabilityHasDataSource(
      capability: capability,
      activeDataSources: request.activeDataSources,
    );
    if (!dataSourceOk) {
      developer.log(
        'data-source gate blocked capability ${capability.capabilityKey}: required=${capability.requiresDataSource}.',
        name: 'zara',
      );
      return ZaraTurnResult(
        text: zaraCapabilityDataSourceMessage(capability: capability),
        decision: ZaraDecision.refusedDataSource,
        providerLabel: _gatedProviderLabel,
        capabilityKey: capability.capabilityKey,
        internalReason:
            'required data source ${capability.requiresDataSource} not active',
      );
    }

    final systemPrompt = buildZaraSystemPrompt(
      capability: capability,
      activeAllowanceTier: request.allowanceTier,
      activeDataSources: request.activeDataSources,
      boundSiteId: request.siteId,
      siteContextSummary: request.siteContext?.contextSummary,
      siteContextObservedAtUtc: request.siteContext?.observedAtUtc,
    );

    final tools = toolRegistry.definitionsForCapability(
      capability.capabilityKey,
    );
    final messages = <LlmMessage>[
      LlmMessage(role: LlmMessageRole.user, text: request.userMessage),
    ];
    final toolContext = ZaraToolContext(
      clientId: request.clientId,
      siteId: request.siteId,
    );

    LlmResponse? lastResponse;
    for (var iteration = 0; iteration < _maxToolIterations; iteration++) {
      try {
        final response = await llmProvider.complete(
          messages: messages,
          systemPrompt: systemPrompt,
          tools: tools,
          serviceLevel: LlmServiceLevel.primary,
          maxOutputTokens: 220,
        );
        lastResponse = response;

        if (!response.hasToolCalls) {
          final text = response.text.trim();
          if (text.isEmpty) {
            developer.log(
              'provider returned empty text for ${capability.capabilityKey} '
              'on iteration $iteration',
              name: 'zara',
            );
            return _fallback(
              capabilityKey: capability.capabilityKey,
              internalReason:
                  'provider returned empty text on iteration $iteration',
            );
          }

          return ZaraTurnResult(
            text: text,
            decision: ZaraDecision.delegated,
            providerLabel: response.providerLabel,
            capabilityKey: capability.capabilityKey,
          );
        }

        messages.add(
          LlmMessage(
            role: LlmMessageRole.assistant,
            text: response.text,
            toolCalls: response.toolCalls,
          ),
        );

        for (final call in response.toolCalls) {
          final tool = toolRegistry.toolByName(call.toolName);
          ZaraToolExecutionResult result;
          if (tool == null) {
            developer.log(
              'tool ${call.toolName} not registered for '
              '${capability.capabilityKey}',
              name: 'zara',
            );
            result = ZaraToolExecutionResult.error(
              'tool ${call.toolName} not registered',
            );
          } else {
            try {
              result = await tool.execute(call.input, toolContext);
            } catch (error, stackTrace) {
              developer.log(
                'tool ${call.toolName} threw',
                name: 'zara',
                error: error,
                stackTrace: stackTrace,
              );
              result = ZaraToolExecutionResult.error(
                'tool execution failed: $error',
              );
            }
          }

          messages.add(
            LlmMessage(
              role: LlmMessageRole.tool,
              toolName: call.toolName,
              toolUseId: call.id,
              text: jsonEncode(result.output),
              isError: result.isError,
            ),
          );
        }
      } catch (error, stackTrace) {
        developer.log(
          'provider call failed for ${capability.capabilityKey} '
          'on iteration $iteration',
          name: 'zara',
          error: error,
          stackTrace: stackTrace,
        );
        return _fallback(
          capabilityKey: capability.capabilityKey,
          internalReason: 'provider error: $error',
        );
      }
    }

    developer.log(
      'tool loop iteration cap ($_maxToolIterations) hit for '
      '${capability.capabilityKey}',
      name: 'zara',
    );
    final fallbackText = lastResponse?.text.trim() ?? '';
    if (fallbackText.isNotEmpty && lastResponse != null) {
      return ZaraTurnResult(
        text: fallbackText,
        decision: ZaraDecision.delegated,
        providerLabel: lastResponse.providerLabel,
        capabilityKey: capability.capabilityKey,
      );
    }
    return _fallback(
      capabilityKey: capability.capabilityKey,
      internalReason: 'tool loop iteration cap hit without terminal text',
    );
  }

  ZaraTurnResult _fallback({String? capabilityKey, String? internalReason}) {
    return ZaraTurnResult(
      text: _fallbackText,
      decision: ZaraDecision.fallback,
      providerLabel: _fallbackProviderLabel,
      capabilityKey: capabilityKey,
      internalReason: internalReason,
      usedFallback: true,
    );
  }
}
