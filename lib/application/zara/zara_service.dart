import 'dart:async';
import 'dart:developer' as developer;

import 'capability_registry.dart';
import 'llm_provider.dart';
import 'system_prompt.dart';

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
  final ZaraCapabilityTier activeTier;
  final Iterable<String> activeDataSources;
  final ZaraSiteContext? siteContext;

  const ZaraTurnRequest({
    required this.userMessage,
    required this.audience,
    this.clientId,
    this.siteId,
    required this.activeTier,
    this.activeDataSources = const <String>[],
    this.siteContext,
  });
}

/// Outcome shape, with the four code paths explicit.
enum ZaraDecision { delegated, refusedTier, refusedDataSource, fallback }

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

  const footfallPhrases = <String>[
    'footfall',
    'foot traffic',
    'how many people',
    'how many came',
    'how many visitors',
    'visitor count',
    'people count',
  ];
  if (footfallPhrases.any(normalised.contains)) {
    return zaraCapabilityByKey('footfall_count');
  }

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

  const statusPhrases = <String>[
    'all clear',
    'all good',
    'site status',
    'status check',
    'anything to report',
    "what's happening",
    'whats happening',
    'how are things',
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
/// - Classifier recognises three capability keys (see _classifyCapability).
///   Unmatched messages return ZaraDecision.fallback.
/// - LlmServiceLevel.primary only. No escalation routing.
/// - On provider failure, returns deterministic fallback. Does not improvise.
/// - request.audience and request.siteContext are unused in v1; reserved for
///   future prompt-builder expansion.
class ProviderBackedZaraService implements ZaraService {
  final LlmProvider llmProvider;

  const ProviderBackedZaraService({required this.llmProvider});

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

    final tierOk = zaraTierAllowsCapability(
      activeTier: request.activeTier,
      capability: capability,
    );
    if (!tierOk) {
      developer.log(
        'tier gate blocked capability ${capability.capabilityKey}: active=${request.activeTier.name}, required=${capability.minTier.name}.',
        name: 'zara',
      );
      return ZaraTurnResult(
        text: zaraCapabilityUpsellMessage(
          capability: capability,
          activeTier: request.activeTier,
        ),
        decision: ZaraDecision.refusedTier,
        providerLabel: _gatedProviderLabel,
        capabilityKey: capability.capabilityKey,
        internalReason:
            'tier ${request.activeTier.name} below required ${capability.minTier.name}',
      );
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
      activeTier: request.activeTier,
      activeDataSources: request.activeDataSources,
    );

    try {
      final response = await llmProvider.complete(
        messages: <LlmMessage>[
          LlmMessage(role: LlmMessageRole.user, text: request.userMessage),
        ],
        systemPrompt: systemPrompt,
        serviceLevel: LlmServiceLevel.primary,
        maxOutputTokens: 220,
      );

      final text = response.text.trim();
      if (text.isEmpty) {
        developer.log(
          'provider returned empty text for ${capability.capabilityKey}',
          name: 'zara',
        );
        return _fallback(
          capabilityKey: capability.capabilityKey,
          internalReason: 'provider returned empty text',
        );
      }

      return ZaraTurnResult(
        text: text,
        decision: ZaraDecision.delegated,
        providerLabel: response.providerLabel,
        capabilityKey: capability.capabilityKey,
      );
    } catch (error, stackTrace) {
      developer.log(
        'provider call failed for ${capability.capabilityKey}',
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
