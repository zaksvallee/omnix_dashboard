import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/authority/operator_context.dart';
import '../domain/evidence/client_ledger_service.dart';
import '../domain/intelligence/risk_policy.dart';
import '../domain/store/in_memory_event_store.dart';
import '../infrastructure/events/supabase_client_ledger_repository.dart';
import '../engine/execution/execution_engine.dart';
import 'dispatch_application_service.dart';

class AppState {
  static const _operatorIdEnv = String.fromEnvironment(
    'ONYX_OPERATOR_ID',
    defaultValue: 'OPERATOR-01',
  );
  final InMemoryEventStore store;
  final DispatchApplicationService service;

  AppState._(this.store, this.service);

  factory AppState.initial() {
    final supabase = Supabase.instance.client;
    final store = InMemoryEventStore(
      supabaseClient: supabase,
      restoreSiteId: 'SITE-SANDTON',
    );
    unawaited(store.restoreFromSupabase());
    final engine = ExecutionEngine();
    const policy = RiskPolicy(escalationThreshold: 70);
    final repository = SupabaseClientLedgerRepository(supabase);

    final operator = OperatorContext(
      operatorId: _operatorIdEnv.trim().isEmpty
          ? 'OPERATOR-01'
          : _operatorIdEnv.trim(),
      allowedRegions: {'REGION-GAUTENG'},
      allowedSites: {'SITE-SANDTON'},
    );

    final service = DispatchApplicationService(
      store: store,
      engine: engine,
      policy: policy,
      ledgerService: ClientLedgerService(repository),
      operator: operator,
    );

    return AppState._(store, service);
  }
}
