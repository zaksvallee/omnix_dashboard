import '../domain/intelligence/news_item.dart';
import '../domain/intelligence/decision_service.dart';
import '../domain/authority/authority_token.dart';
import '../domain/authority/operator_context.dart';
import '../engine/execution/execution_engine.dart';
import '../domain/store/event_store.dart';
import '../domain/intelligence/risk_policy.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/projection/dispatch_projection.dart';
import '../domain/testing/replay_consistency_verifier.dart';
import '../domain/evidence/client_ledger_service.dart';

class DispatchApplicationService {
  final EventStore store;
  final ExecutionEngine engine;
  final RiskPolicy policy;
  final ClientLedgerService ledgerService;
  final OperatorContext operator;

  DispatchApplicationService({
    required this.store,
    required this.engine,
    required this.policy,
    required this.ledgerService,
    required this.operator,
  });

  void _verifyReplay() {
    ReplayConsistencyVerifier.verify(store.allEvents());
  }

  void processIntelligenceDemo({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final news = NewsItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Simulated High Risk',
      source: clientId,
      summary: 'Generated from UI',
      riskScore: 85,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    final decisionService = DecisionService(policy);

    final DecisionCreated? decision = decisionService.evaluate(
      news,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    if (decision == null) return;

    store.append(decision);
    _verifyReplay();
  }

  Future<void> execute({
    required String clientId,
    required String regionId,
    required String siteId,
    required String dispatchId,
  }) async {
    final projection = DispatchProjection();

    for (final event in store.allEvents()) {
      projection.apply(event);
    }

    final status = projection.statusOf(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      dispatchId: dispatchId,
    );

    if (status != 'DECIDED') return;

    // 🔒 Authority Boundary
    if (!operator.canExecute(regionId: regionId, siteId: siteId)) {
      final denied = ExecutionDenied(
        eventId: DateTime.now().microsecondsSinceEpoch.toString(),
        sequence: 0,
        version: 1,
        occurredAt: DateTime.now().toUtc(),
        dispatchId: dispatchId,
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
        operatorId: operator.operatorId,
        reason: 'Operator not authorized for region/site',
      );

      store.append(denied);
      _verifyReplay();
      return;
    }

    final authority = AuthorityToken(
      authorizedBy: operator.operatorId,
      timestamp: DateTime.now(),
    );

    engine.execute(dispatchId, authority: authority);

    final executionEvent = ExecutionCompleted(
      eventId: DateTime.now().microsecondsSinceEpoch.toString(),
      sequence: 0,
      version: 1,
      occurredAt: DateTime.now().toUtc(),
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      dispatchId: dispatchId,
      success: true,
    );

    store.append(executionEvent);

    _verifyReplay();

    await ledgerService.sealDispatch(
      clientId: clientId,
      dispatchId: dispatchId,
      events: store.allEvents(),
    );
  }
}
