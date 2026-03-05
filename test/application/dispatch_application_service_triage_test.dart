import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dispatch_application_service.dart';
import 'package:omnix_dashboard/domain/authority/operator_context.dart';
import 'package:omnix_dashboard/domain/evidence/client_ledger_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';
import 'package:omnix_dashboard/domain/intelligence/risk_policy.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/engine/execution/execution_engine.dart';
import 'package:omnix_dashboard/infrastructure/events/in_memory_client_ledger_repository.dart';

void main() {
  DispatchApplicationService buildService() {
    final store = InMemoryEventStore();
    return DispatchApplicationService(
      store: store,
      engine: ExecutionEngine(),
      policy: const RiskPolicy(escalationThreshold: 70),
      ledgerService: ClientLedgerService(InMemoryClientLedgerRepository()),
      operator: const OperatorContext(
        operatorId: 'OP-1',
        allowedRegions: {'REGION-GAUTENG'},
        allowedSites: {'SITE-SANDTON'},
      ),
    );
  }

  test('auto creates dispatch decision for corroborated high-risk batch', () {
    final service = buildService();
    final now = DateTime.utc(2026, 3, 6, 14, 0);
    final records = [
      NormalizedIntelRecord(
        provider: 'watchtower',
        sourceType: 'news',
        externalId: 'WT-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Armed suspects seen near gate B',
        summary: 'Vehicle loitering and perimeter pressure',
        riskScore: 88,
        occurredAtUtc: now,
      ),
      NormalizedIntelRecord(
        provider: 'community-feed',
        sourceType: 'community',
        externalId: 'CF-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Community reports armed suspects near gate B',
        summary: 'Same vehicle loitering by perimeter',
        riskScore: 72,
        occurredAtUtc: now.add(const Duration(minutes: 2)),
      ),
    ];

    final outcome = service.ingestNormalizedIntelligence(records: records);

    expect(outcome.appendedIntelligence, 2);
    expect(outcome.createdDecisions, 1);
    expect(outcome.advisoryCount, 0);
    expect(outcome.watchCount, 1);
    expect(outcome.dispatchCandidateCount, 1);
    expect(
      service.store.allEvents().whereType<DecisionCreated>(),
      hasLength(1),
    );
  });

  test('does not auto escalate isolated high-risk signal', () {
    final service = buildService();
    final now = DateTime.utc(2026, 3, 6, 14, 30);
    final records = [
      NormalizedIntelRecord(
        provider: 'watchtower',
        sourceType: 'news',
        externalId: 'WT-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'High-risk perimeter alert',
        summary: 'Single-source signal only',
        riskScore: 90,
        occurredAtUtc: now,
      ),
    ];

    final outcome = service.ingestNormalizedIntelligence(records: records);

    expect(outcome.appendedIntelligence, 1);
    expect(outcome.createdDecisions, 0);
    expect(outcome.advisoryCount, 0);
    expect(outcome.watchCount, 1);
    expect(outcome.dispatchCandidateCount, 0);
    expect(
      service.store.allEvents().whereType<DecisionCreated>(),
      isEmpty,
    );
  });
}
