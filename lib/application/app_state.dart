import '../domain/store/in_memory_event_store.dart';
import '../engine/execution/execution_engine.dart';
import '../domain/intelligence/risk_policy.dart';
import '../domain/evidence/client_ledger_service.dart';
import '../domain/authority/operator_context.dart';
import '../infrastructure/events/supabase_client_ledger_repository.dart';
import 'dispatch_application_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppState {
  final InMemoryEventStore store;
  final DispatchApplicationService service;

  AppState._(this.store, this.service);

  factory AppState.initial() {
    final store = InMemoryEventStore();
    final engine = ExecutionEngine();
    const policy = RiskPolicy(escalationThreshold: 70);

    final supabase = Supabase.instance.client;
    final repository = SupabaseClientLedgerRepository(supabase);

    final operator = OperatorContext(
      operatorId: 'OPERATOR-01',
      allowedRegions: {
        'REGION-GAUTENG',
      },
      allowedSites: {
        'SITE-SANDTON',
      },
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
