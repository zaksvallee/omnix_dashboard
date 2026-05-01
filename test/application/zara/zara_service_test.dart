import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/zara/capability_registry.dart';
import 'package:omnix_dashboard/application/zara/llm_provider.dart';
import 'package:omnix_dashboard/application/zara/zara_service.dart';

class _FakeLlmProvider implements LlmProvider {
  final bool configured;
  final LlmResponse Function()? onComplete;
  final Object? thrownError;

  int callCount = 0;

  _FakeLlmProvider({
    this.configured = true,
    this.onComplete,
    this.thrownError,
  });

  @override
  bool get isConfigured => configured;

  @override
  Future<LlmResponse> complete({
    required List<LlmMessage> messages,
    String? systemPrompt,
    List<LlmTool> tools = const <LlmTool>[],
    LlmServiceLevel serviceLevel = LlmServiceLevel.primary,
    int? maxOutputTokens,
  }) async {
    callCount += 1;
    final error = thrownError;
    if (error != null) {
      throw error;
    }
    return onComplete?.call() ??
        const LlmResponse(
          text: 'Monitoring active. Perimeter clear.',
          providerLabel: 'fake:test-provider',
          modelId: 'fake-model',
        );
  }
}

void main() {
  group('classifyZaraCapability', () {
    test('matches the seeded live-smoke phrases', () {
      expect(
        classifyZaraCapability('all clear at the gate')?.capabilityKey,
        'monitoring_status_brief',
      );
      expect(
        classifyZaraCapability('Summarise the incident')?.capabilityKey,
        'incident_summary_reply',
      );
      expect(
        classifyZaraCapability('how many people came today')?.capabilityKey,
        'footfall_count',
      );
      expect(classifyZaraCapability('Hello'), isNull);
    });
  });

  group('ProviderBackedZaraService.handleTurn', () {
    test('delegated path returns provider text for monitoring brief', () async {
      final provider = _FakeLlmProvider(
        onComplete: () => const LlmResponse(
          text: 'Monitoring active. Perimeter clear.',
          providerLabel: 'fake:test-provider',
          modelId: 'fake-model',
        ),
      );
      final service = ProviderBackedZaraService(llmProvider: provider);

      final result = await service.handleTurn(
        const ZaraTurnRequest(
          userMessage: 'all clear',
          audience: ZaraAudience.client,
          activeTier: ZaraCapabilityTier.standard,
        ),
      );

      expect(result.decision, ZaraDecision.delegated);
      expect(result.text, 'Monitoring active. Perimeter clear.');
      expect(result.capabilityKey, 'monitoring_status_brief');
      expect(result.usedFallback, isFalse);
      expect(provider.callCount, 1);
    });

    test('refusedTier path blocks footfall at standard tier', () async {
      final provider = _FakeLlmProvider();
      final service = ProviderBackedZaraService(llmProvider: provider);

      final result = await service.handleTurn(
        const ZaraTurnRequest(
          userMessage: 'footfall',
          audience: ZaraAudience.client,
          activeTier: ZaraCapabilityTier.standard,
        ),
      );

      expect(result.decision, ZaraDecision.refusedTier);
      expect(result.capabilityKey, 'footfall_count');
      expect(result.providerLabel, 'gated');
      expect(result.text, contains('Tactical'));
      expect(result.text, contains('Footfall analytics sit in Tactical'));
      expect(provider.callCount, 0);
    });

    test(
      'refusedDataSource path blocks footfall without its required data source',
      () async {
        final provider = _FakeLlmProvider();
        final service = ProviderBackedZaraService(llmProvider: provider);

        // Note: report_narrative_draft would be the natural Standard-tier example
        // for this path, but is unreachable through the v1 classifier. Using
        // footfall_count at Tactical tier instead — same code path exercised.
        // TODO(zara): add a Standard-tier data-source test when the classifier
        // expands to cover it.
        final result = await service.handleTurn(
          const ZaraTurnRequest(
            userMessage: 'foot traffic',
            audience: ZaraAudience.client,
            activeTier: ZaraCapabilityTier.tactical,
          ),
        );

        expect(result.decision, ZaraDecision.refusedDataSource);
        expect(result.capabilityKey, 'footfall_count');
        expect(result.providerLabel, 'gated');
        expect(result.text, contains('cv_pipeline_footfall'));
        expect(result.text, contains('Footfall Count'));
        expect(provider.callCount, 0);
      },
    );

    test('fallback on no capability match returns deterministic fallback', () async {
      final provider = _FakeLlmProvider();
      final service = ProviderBackedZaraService(llmProvider: provider);

      final result = await service.handleTurn(
        const ZaraTurnRequest(
          userMessage: "what's the weather",
          audience: ZaraAudience.client,
          activeTier: ZaraCapabilityTier.standard,
        ),
      );

      expect(result.decision, ZaraDecision.fallback);
      expect(result.capabilityKey, isNull);
      expect(result.text, 'Message received. Monitoring continues.');
      expect(result.usedFallback, isTrue);
      expect(provider.callCount, 0);
    });

    test('fallback on provider empty text carries through capability key', () async {
      final provider = _FakeLlmProvider(
        onComplete: () => const LlmResponse(
          text: '   ',
          providerLabel: 'fake:test-provider',
          modelId: 'fake-model',
        ),
      );
      final service = ProviderBackedZaraService(llmProvider: provider);

      final result = await service.handleTurn(
        const ZaraTurnRequest(
          userMessage: 'status check',
          audience: ZaraAudience.client,
          activeTier: ZaraCapabilityTier.standard,
        ),
      );

      expect(result.decision, ZaraDecision.fallback);
      expect(result.capabilityKey, 'monitoring_status_brief');
      expect(result.usedFallback, isTrue);
      expect(provider.callCount, 1);
    });

    test('fallback on provider exception does not crash', () async {
      final provider = _FakeLlmProvider(
        thrownError: StateError('provider exploded'),
      );
      final service = ProviderBackedZaraService(llmProvider: provider);

      final result = await service.handleTurn(
        const ZaraTurnRequest(
          userMessage: 'all good',
          audience: ZaraAudience.client,
          activeTier: ZaraCapabilityTier.standard,
        ),
      );

      expect(result.decision, ZaraDecision.fallback);
      expect(result.capabilityKey, 'monitoring_status_brief');
      expect(result.usedFallback, isTrue);
      expect(provider.callCount, 1);
    });

    test('unconfigured provider returns fallback without network call', () async {
      final provider = _FakeLlmProvider(configured: false);
      final service = ProviderBackedZaraService(llmProvider: provider);

      final result = await service.handleTurn(
        const ZaraTurnRequest(
          userMessage: 'all clear',
          audience: ZaraAudience.client,
          activeTier: ZaraCapabilityTier.standard,
        ),
      );

      expect(result.decision, ZaraDecision.fallback);
      expect(result.internalReason, contains('not configured'));
      expect(result.usedFallback, isTrue);
      expect(provider.callCount, 0);
    });
  });
}
