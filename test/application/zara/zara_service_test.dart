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
          allowanceTier: ZaraAllowanceTier.standard,
        ),
      );

      expect(result.decision, ZaraDecision.delegated);
      expect(result.text, 'Monitoring active. Perimeter clear.');
      expect(result.capabilityKey, 'monitoring_status_brief');
      expect(result.usedFallback, isFalse);
      expect(provider.callCount, 1);
    });

    test(
      'standard allowance still allows footfall when the site data source is active',
      () async {
        final provider = _FakeLlmProvider(
          onComplete: () => const LlmResponse(
            text: 'Footfall today is 14 people.',
            providerLabel: 'fake:test-provider',
            modelId: 'fake-model',
          ),
        );
        final service = ProviderBackedZaraService(llmProvider: provider);

        final result = await service.handleTurn(
          const ZaraTurnRequest(
            userMessage: 'footfall',
            audience: ZaraAudience.client,
            allowanceTier: ZaraAllowanceTier.standard,
            activeDataSources: <String>{'cv_pipeline_footfall'},
          ),
        );

        expect(result.decision, ZaraDecision.delegated);
        expect(result.capabilityKey, 'footfall_count');
        expect(result.text, 'Footfall today is 14 people.');
        expect(provider.callCount, 1);
      },
    );

    test(
      'refusedDataSource path blocks footfall when the site data source is inactive',
      () async {
        final provider = _FakeLlmProvider();
        final service = ProviderBackedZaraService(llmProvider: provider);

        final result = await service.handleTurn(
          const ZaraTurnRequest(
            userMessage: 'foot traffic',
            audience: ZaraAudience.client,
            allowanceTier: ZaraAllowanceTier.standard,
          ),
        );

        expect(result.decision, ZaraDecision.refusedDataSource);
        expect(result.capabilityKey, 'footfall_count');
        expect(result.providerLabel, 'gated');
        expect(result.text, contains('CV pipeline footfall'));
        expect(result.text, contains('account manager'));
        expect(provider.callCount, 0);
      },
    );

    test(
      'fallback on no capability match returns deterministic fallback',
      () async {
        final provider = _FakeLlmProvider();
        final service = ProviderBackedZaraService(llmProvider: provider);

        final result = await service.handleTurn(
          const ZaraTurnRequest(
            userMessage: "what's the weather",
            audience: ZaraAudience.client,
            allowanceTier: ZaraAllowanceTier.standard,
          ),
        );

        expect(result.decision, ZaraDecision.fallback);
        expect(result.capabilityKey, isNull);
        expect(result.text, 'Message received. Monitoring continues.');
        expect(result.usedFallback, isTrue);
        expect(provider.callCount, 0);
      },
    );

    test(
      'fallback on provider empty text carries through capability key',
      () async {
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
            allowanceTier: ZaraAllowanceTier.standard,
          ),
        );

        expect(result.decision, ZaraDecision.fallback);
        expect(result.capabilityKey, 'monitoring_status_brief');
        expect(result.usedFallback, isTrue);
        expect(provider.callCount, 1);
      },
    );

    test('fallback on provider exception does not crash', () async {
      final provider = _FakeLlmProvider(
        thrownError: StateError('provider exploded'),
      );
      final service = ProviderBackedZaraService(llmProvider: provider);

      final result = await service.handleTurn(
        const ZaraTurnRequest(
          userMessage: 'all good',
          audience: ZaraAudience.client,
          allowanceTier: ZaraAllowanceTier.standard,
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
          allowanceTier: ZaraAllowanceTier.standard,
        ),
      );

      expect(result.decision, ZaraDecision.fallback);
      expect(result.internalReason, contains('not configured'));
      expect(result.usedFallback, isTrue);
      expect(provider.callCount, 0);
    });
  });
}
