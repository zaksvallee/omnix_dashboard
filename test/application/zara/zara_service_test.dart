import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/zara/capability_registry.dart';
import 'package:omnix_dashboard/application/zara/llm_provider.dart';
import 'package:omnix_dashboard/application/zara/tools/zara_tool.dart';
import 'package:omnix_dashboard/application/zara/tools/zara_tool_registry.dart';
import 'package:omnix_dashboard/application/zara/zara_service.dart';

class _FakeLlmProvider implements LlmProvider {
  final bool configured;
  final List<LlmResponse> scriptedResponses;
  final LlmResponse Function(_FakeLlmProvider provider)? onComplete;
  final Object? thrownError;

  int callCount = 0;
  String? lastSystemPrompt;
  List<LlmMessage> lastMessages = const <LlmMessage>[];
  List<List<LlmMessage>> messagesByCall = <List<LlmMessage>>[];
  List<List<LlmTool>> toolsByCall = <List<LlmTool>>[];

  _FakeLlmProvider({
    this.configured = true,
    this.scriptedResponses = const <LlmResponse>[],
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
    lastSystemPrompt = systemPrompt;
    lastMessages = List<LlmMessage>.from(messages);
    messagesByCall.add(List<LlmMessage>.from(messages));
    toolsByCall.add(List<LlmTool>.from(tools));
    final error = thrownError;
    if (error != null) {
      throw error;
    }
    final scripted = onComplete;
    if (scripted != null) {
      return scripted(this);
    }
    final index = callCount - 1;
    if (index < scriptedResponses.length) {
      return scriptedResponses[index];
    }
    return const LlmResponse(
      text: 'Monitoring active. Perimeter clear.',
      providerLabel: 'fake:test-provider',
      modelId: 'fake-model',
    );
  }
}

class _FakeTool implements ZaraTool {
  final LlmTool _definition;
  final Future<ZaraToolExecutionResult> Function(
    Map<String, Object?> input,
    ZaraToolContext context,
  )
  _onExecute;

  int callCount = 0;
  List<Map<String, Object?>> inputs = <Map<String, Object?>>[];
  List<ZaraToolContext> contexts = <ZaraToolContext>[];

  _FakeTool({
    required String name,
    required Future<ZaraToolExecutionResult> Function(
      Map<String, Object?> input,
      ZaraToolContext context,
    )
    onExecute,
  }) : _definition = LlmTool(
         name: name,
         description: 'Fake tool for tests.',
         inputSchema: const <String, Object?>{
           'type': 'object',
           'properties': <String, Object?>{},
         },
       ),
       _onExecute = onExecute;

  @override
  LlmTool get definition => _definition;

  @override
  Future<ZaraToolExecutionResult> execute(
    Map<String, Object?> input,
    ZaraToolContext context,
  ) async {
    callCount += 1;
    inputs.add(Map<String, Object?>.from(input));
    contexts.add(context);
    return _onExecute(input, context);
  }
}

ZaraToolRegistry _peakOccupancyToolRegistry(ZaraTool tool) {
  return ZaraToolRegistry(
    toolsByName: <String, ZaraTool>{tool.definition.name: tool},
    capabilityToToolNames: <String, List<String>>{
      'peak_occupancy': <String>[tool.definition.name],
    },
  );
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
        classifyZaraCapability('peak occupancy today')?.capabilityKey,
        'peak_occupancy',
      );
      expect(
        classifyZaraCapability('how many people came today'),
        isNull,
        reason:
            'visitor-shaped questions intentionally drop to fallback after rename',
      );
      expect(
        classifyZaraCapability('how many on site right now')?.capabilityKey,
        'monitoring_status_brief',
        reason: 'current-occupancy questions route to monitoring_status_brief',
      );
      expect(classifyZaraCapability('Hello'), isNull);
    });
  });

  group('ProviderBackedZaraService.handleTurn', () {
    test('delegated path returns provider text for monitoring brief', () async {
      final provider = _FakeLlmProvider(
        scriptedResponses: const <LlmResponse>[
          LlmResponse(
            text: 'Monitoring active. Perimeter clear.',
            providerLabel: 'fake:test-provider',
            modelId: 'fake-model',
          ),
        ],
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
      'standard allowance still allows peak_occupancy when the site data source is active',
      () async {
        final provider = _FakeLlmProvider(
          scriptedResponses: const <LlmResponse>[
            LlmResponse(
              text: 'Peak occupancy today is 14 people.',
              providerLabel: 'fake:test-provider',
              modelId: 'fake-model',
            ),
          ],
        );
        final service = ProviderBackedZaraService(llmProvider: provider);

        final result = await service.handleTurn(
          ZaraTurnRequest(
            userMessage: 'peak occupancy',
            audience: ZaraAudience.client,
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            allowanceTier: ZaraAllowanceTier.standard,
            activeDataSources: <String>{'cv_pipeline_occupancy'},
            siteContext: ZaraSiteContext(
              observedAtUtc: DateTime.utc(2026, 5, 1, 10, 29, 39),
              perimeterClear: true,
              humanCount: 8,
              vehicleCount: 0,
              animalCount: 0,
              motionCount: 8,
              activeAlertCount: 0,
              contextSummary:
                  'Perimeter clear. Eight people currently on site.',
            ),
          ),
        );

        expect(result.decision, ZaraDecision.delegated);
        expect(result.capabilityKey, 'peak_occupancy');
        expect(result.text, 'Peak occupancy today is 14 people.');
        expect(provider.callCount, 1);
        expect(provider.lastSystemPrompt, contains('Bound site scope'));
        expect(provider.lastSystemPrompt, contains('SITE-MS-VALLEE-RESIDENCE'));
        expect(
          provider.lastSystemPrompt,
          contains('Do not ask the user to restate the site scope'),
        );
        expect(
          provider.lastSystemPrompt,
          contains(
            'Latest site context: Perimeter clear. Eight people currently on site.',
          ),
        );
      },
    );

    test(
      'refusedDataSource path blocks peak_occupancy when the site data source is inactive',
      () async {
        final provider = _FakeLlmProvider();
        final service = ProviderBackedZaraService(llmProvider: provider);

        final result = await service.handleTurn(
          const ZaraTurnRequest(
            userMessage: 'peak occupancy',
            audience: ZaraAudience.client,
            allowanceTier: ZaraAllowanceTier.standard,
          ),
        );

        expect(result.decision, ZaraDecision.refusedDataSource);
        expect(result.capabilityKey, 'peak_occupancy');
        expect(result.providerLabel, 'gated');
        expect(result.text, contains('CV pipeline occupancy'));
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
          scriptedResponses: const <LlmResponse>[
            LlmResponse(
              text: '   ',
              providerLabel: 'fake:test-provider',
              modelId: 'fake-model',
            ),
          ],
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

    test(
      'unconfigured provider returns fallback without network call',
      () async {
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
      },
    );

    test(
      'tool loop happy path executes tool and feeds its result back to the provider',
      () async {
        final tool = _FakeTool(
          name: 'fetch_peak_occupancy',
          onExecute: (input, context) async {
            return const ZaraToolExecutionResult(
              output: <String, Object?>{
                'peak_count': 47,
                'session_date': '2026-05-01',
              },
            );
          },
        );
        final provider = _FakeLlmProvider(
          scriptedResponses: const <LlmResponse>[
            LlmResponse(
              text: '',
              providerLabel: 'fake:test-provider',
              modelId: 'fake-model',
              toolCalls: <LlmToolCall>[
                LlmToolCall(
                  id: 'call-1',
                  toolName: 'fetch_peak_occupancy',
                  input: <String, Object?>{'time_window': 'local_site_day'},
                ),
              ],
            ),
            LlmResponse(
              text: 'Peak occupancy today is 47 people.',
              providerLabel: 'fake:test-provider',
              modelId: 'fake-model',
            ),
          ],
        );
        final service = ProviderBackedZaraService(
          llmProvider: provider,
          toolRegistry: _peakOccupancyToolRegistry(tool),
        );

        final result = await service.handleTurn(
          const ZaraTurnRequest(
            userMessage: 'peak occupancy today',
            audience: ZaraAudience.client,
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            allowanceTier: ZaraAllowanceTier.standard,
            activeDataSources: <String>{'cv_pipeline_occupancy'},
          ),
        );

        expect(result.decision, ZaraDecision.delegated);
        expect(result.text, 'Peak occupancy today is 47 people.');
        expect(provider.callCount, 2);
        expect(provider.toolsByCall.first, hasLength(1));
        expect(provider.toolsByCall.first.single.name, 'fetch_peak_occupancy');
        expect(tool.callCount, 1);
        expect(tool.inputs.single['time_window'], 'local_site_day');
        expect(tool.contexts.single.clientId, 'CLIENT-MS-VALLEE');
        expect(tool.contexts.single.siteId, 'SITE-MS-VALLEE-RESIDENCE');

        final secondCallMessages = provider.messagesByCall[1];
        expect(secondCallMessages, hasLength(3));
        expect(secondCallMessages[0].role, LlmMessageRole.user);
        expect(secondCallMessages[1].role, LlmMessageRole.assistant);
        expect(secondCallMessages[1].toolCalls, hasLength(1));
        expect(secondCallMessages[2].role, LlmMessageRole.tool);
        expect(secondCallMessages[2].toolName, 'fetch_peak_occupancy');
        expect(secondCallMessages[2].toolUseId, 'call-1');
        expect(secondCallMessages[2].isError, isFalse);
        expect(
          jsonDecode(secondCallMessages[2].text) as Map<String, dynamic>,
          containsPair('peak_count', 47),
        );
      },
    );

    test('tool error feeds back into the second provider call', () async {
      final tool = _FakeTool(
        name: 'fetch_peak_occupancy',
        onExecute: (input, context) async {
          throw StateError('database offline');
        },
      );
      final provider = _FakeLlmProvider(
        scriptedResponses: const <LlmResponse>[
          LlmResponse(
            text: '',
            providerLabel: 'fake:test-provider',
            modelId: 'fake-model',
            toolCalls: <LlmToolCall>[
              LlmToolCall(
                id: 'call-2',
                toolName: 'fetch_peak_occupancy',
                input: <String, Object?>{'time_window': 'local_site_day'},
              ),
            ],
          ),
          LlmResponse(
            text:
                'I could not fetch the count just now, but monitoring continues.',
            providerLabel: 'fake:test-provider',
            modelId: 'fake-model',
          ),
        ],
      );
      final service = ProviderBackedZaraService(
        llmProvider: provider,
        toolRegistry: _peakOccupancyToolRegistry(tool),
      );

      final result = await service.handleTurn(
        const ZaraTurnRequest(
          userMessage: 'peak occupancy today',
          audience: ZaraAudience.client,
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          allowanceTier: ZaraAllowanceTier.standard,
          activeDataSources: <String>{'cv_pipeline_occupancy'},
        ),
      );

      expect(result.decision, ZaraDecision.delegated);
      expect(
        result.text,
        'I could not fetch the count just now, but monitoring continues.',
      );
      expect(provider.callCount, 2);
      expect(tool.callCount, 1);

      final toolMessage = provider.messagesByCall[1].last;
      expect(toolMessage.role, LlmMessageRole.tool);
      expect(toolMessage.isError, isTrue);
      final payload = jsonDecode(toolMessage.text) as Map<String, dynamic>;
      expect(payload['error'], contains('tool execution failed'));
    });

    test(
      'iteration cap returns the last provider text when tool calls never terminate',
      () async {
        final tool = _FakeTool(
          name: 'fetch_peak_occupancy',
          onExecute: (input, context) async {
            return const ZaraToolExecutionResult(
              output: <String, Object?>{'peak_count': 47},
            );
          },
        );
        final provider = _FakeLlmProvider(
          onComplete: (provider) {
            final callId = 'loop-${provider.callCount}';
            return LlmResponse(
              text: 'Need another lookup.',
              providerLabel: 'fake:test-provider',
              modelId: 'fake-model',
              toolCalls: <LlmToolCall>[
                LlmToolCall(
                  id: callId,
                  toolName: 'fetch_peak_occupancy',
                  input: const <String, Object?>{
                    'time_window': 'local_site_day',
                  },
                ),
              ],
            );
          },
        );
        final service = ProviderBackedZaraService(
          llmProvider: provider,
          toolRegistry: _peakOccupancyToolRegistry(tool),
        );

        final result = await service.handleTurn(
          const ZaraTurnRequest(
            userMessage: 'peak occupancy today',
            audience: ZaraAudience.client,
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            allowanceTier: ZaraAllowanceTier.standard,
            activeDataSources: <String>{'cv_pipeline_occupancy'},
          ),
        );

        expect(provider.callCount, 5);
        expect(tool.callCount, 5);
        expect(result.decision, ZaraDecision.delegated);
        expect(result.text, 'Need another lookup.');
        expect(result.capabilityKey, 'peak_occupancy');
      },
    );
  });
}
