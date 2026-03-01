import '../domain/intelligence/decision_service.dart';
import '../domain/intelligence/news_item.dart';
import '../domain/intelligence/risk_policy.dart';
import '../domain/events/execution_completed.dart';
import '../domain/store/in_memory_event_store.dart';
import '../domain/projection/dispatch_projection.dart';
import '../engine/execution/execution_engine.dart';
import '../domain/authority/authority_token.dart';
import '../domain/testing/replay_consistency_verifier.dart';
import '../engine/dispatch/dispatch_state_machine.dart';
import '../engine/dispatch/action_status.dart';

class VerticalSliceRunner {
  static void run() {
    final store = InMemoryEventStore();
    final projection = DispatchProjection();
    final engine = ExecutionEngine();

    const policy = RiskPolicy();
    const clientId = 'CLIENT-1';
    const regionId = 'REGION-1';
    const siteId = 'SITE-1';

    final decisionService = DecisionService(policy);

    const news = NewsItem(
      id: 'NEWS-001',
      title: 'Manual threat signal',
      source: 'manual',
      summary: 'High risk manual escalation test',
      riskScore: 90,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    final decision = decisionService.evaluate(
      news,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    if (decision == null) {
      throw StateError('Escalation did not occur as expected.');
    }

    // Append decision
    store.append(decision);
    projection.apply(decision);

    final currentStatus = projection.statusOf(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      dispatchId: decision.dispatchId,
    );

    if (currentStatus != 'DECIDED') {
      throw StateError('Expected DECIDED state before execution.');
    }

    // Enforce state machine legality
    final legal = DispatchStateMachine.canTransition(
      ActionStatus.decided,
      ActionStatus.executed,
    );

    if (!legal) {
      throw StateError('Illegal state transition DECIDED → EXECUTED.');
    }

    final authority = AuthorityToken(
      authorizedBy: 'FOUNDER',
      timestamp: DateTime.now().toUtc(),
    );

    final success = engine.execute(
      decision.dispatchId,
      authority: authority,
    );

    final executionEvent = ExecutionCompleted(
      eventId: DateTime.now().microsecondsSinceEpoch.toString(),
      sequence: 0,
      version: 1,
      occurredAt: DateTime.now().toUtc(),
      dispatchId: decision.dispatchId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      success: success,
    );

    store.append(executionEvent);
    projection.apply(executionEvent);

    ReplayConsistencyVerifier.verify(store.allEvents());

    final rebuiltProjection = DispatchProjection();
    for (final event in store.allEvents()) {
      rebuiltProjection.apply(event);
    }

    final rebuiltStatus = rebuiltProjection.statusOf(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      dispatchId: decision.dispatchId,
    );

    if (rebuiltStatus != 'EXECUTED') {
      throw StateError('Replay rebuild mismatch.');
    }
  }
}
