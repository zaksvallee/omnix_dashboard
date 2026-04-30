import 'package:supabase_flutter/supabase_flutter.dart';

import '../zara/theatre/zara_action.dart';
import '../zara/theatre/zara_action_executor.dart';
import '../zara/theatre/zara_scenario.dart';

class SupabaseService {
  final SupabaseClient client;

  const SupabaseService({required this.client});

  Future<void> upsertZaraScenario({
    required ZaraScenario scenario,
    String controllerUserId = '',
    String orgId = '',
  }) async {
    await client.from('zara_scenarios').upsert(<String, Object?>{
      'id': scenario.id.value,
      'kind': scenario.kind.name,
      'summary': scenario.summary,
      'origin_event_ids': scenario.originEventIds,
      'lifecycle_state': _scenarioLifecycleLabel(scenario.lifecycleState),
      'created_at': scenario.createdAt.toUtc().toIso8601String(),
      'resolved_at': _resolvedAtValue(scenario),
      if (controllerUserId.trim().isNotEmpty)
        'controller_user_id': controllerUserId.trim(),
      if (orgId.trim().isNotEmpty) 'org_id': orgId.trim(),
    }, onConflict: 'id');
  }

  Future<void> appendZaraActionLog({
    required ZaraScenario scenario,
    required ZaraAction action,
    required ZaraActionExecutionOutcome outcome,
    required Map<String, Object?> resultJson,
    String orgId = '',
  }) async {
    await client.from('zara_action_log').insert(<String, Object?>{
      'scenario_id': scenario.id.value,
      'action_kind': action.kind.name,
      'proposed_at': scenario.createdAt.toUtc().toIso8601String(),
      'outcome': outcome.name,
      'executed_at': DateTime.now().toUtc().toIso8601String(),
      'payload_jsonb': <String, Object?>{
        ...action.payload.toJson(),
        if (action.pendingDraftEdits.trim().isNotEmpty)
          'draft_override': action.pendingDraftEdits.trim(),
      },
      'result_jsonb': resultJson,
      if (orgId.trim().isNotEmpty) 'org_id': orgId.trim(),
    });
  }

  Future<List<Map<String, Object?>>> readZaraScenarios({
    String lifecycleState = '',
  }) async {
    final rows = lifecycleState.trim().isEmpty
        ? await client
              .from('zara_scenarios')
              .select()
              .order('created_at', ascending: false)
        : await client
              .from('zara_scenarios')
              .select()
              .eq('lifecycle_state', lifecycleState.trim())
              .order('created_at', ascending: false);
    return List<Map<String, Object?>>.from(
      (rows as List).map((row) {
        return Map<String, Object?>.from(row as Map);
      }),
    );
  }

  Future<List<Map<String, Object?>>> readZaraActionLog({
    required String scenarioId,
  }) async {
    final rows = await client
        .from('zara_action_log')
        .select()
        .eq('scenario_id', scenarioId)
        .order('proposed_at', ascending: true);
    return List<Map<String, Object?>>.from(
      (rows as List).map((row) {
        return Map<String, Object?>.from(row as Map);
      }),
    );
  }

  String _scenarioLifecycleLabel(ZaraScenarioLifecycleState state) {
    return switch (state) {
      ZaraScenarioLifecycleState.awaitingController => 'awaiting_controller',
      ZaraScenarioLifecycleState.complete => 'complete',
      ZaraScenarioLifecycleState.dismissed => 'dismissed',
      ZaraScenarioLifecycleState.executing => 'executing',
      ZaraScenarioLifecycleState.proposing => 'proposing',
    };
  }

  String? _resolvedAtValue(ZaraScenario scenario) {
    return switch (scenario.lifecycleState) {
      ZaraScenarioLifecycleState.complete ||
      ZaraScenarioLifecycleState.dismissed =>
        DateTime.now().toUtc().toIso8601String(),
      _ => null,
    };
  }
}
