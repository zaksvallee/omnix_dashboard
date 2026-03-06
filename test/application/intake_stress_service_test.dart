import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/dispatch_application_service.dart';
import 'package:omnix_dashboard/application/intake_stress_service.dart';
import 'package:omnix_dashboard/domain/authority/operator_context.dart';
import 'package:omnix_dashboard/domain/evidence/client_ledger_service.dart';
import 'package:omnix_dashboard/domain/intelligence/risk_policy.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/engine/execution/execution_engine.dart';
import 'package:omnix_dashboard/infrastructure/events/in_memory_client_ledger_repository.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';

void main() {
  IntakeStressService buildService() {
    final store = InMemoryEventStore();
    final appService = DispatchApplicationService(
      store: store,
      engine: ExecutionEngine(),
      policy: RiskPolicy(escalationThreshold: 70),
      ledgerService: ClientLedgerService(InMemoryClientLedgerRepository()),
      operator: const OperatorContext(
        operatorId: 'OP-1',
        allowedRegions: {'REGION-GAUTENG'},
        allowedSites: {'SITE-SANDTON'},
      ),
    );
    return IntakeStressService(store: store, service: appService);
  }

  group('IntakeStressService', () {
    test('caps bursts based on max attempted events', () async {
      final service = buildService();
      var progressCalls = 0;

      final result = await service.run(
        profile: const IntakeStressProfile(
          feeds: 2,
          recordsPerFeed: 100,
          bursts: 5,
          highRiskPercent: 0,
          siteSpread: 1,
          maxAttemptedEvents: 250,
          seed: 42,
          chunkSize: 300,
          duplicatePercent: 0,
          interBurstDelayMs: 0,
          verifyReplay: false,
          stopOnRegression: false,
          regressionThroughputDrop: 20,
          regressionVerifyIncreaseMs: 100,
          maxRegressionPressureSeverity: 2,
          maxRegressionImbalanceSeverity: 2,
          soakRuns: 1,
        ),
        runId: 'STR-CAP',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        primarySiteId: 'SITE-SANDTON',
        shouldCancel: () => false,
        onBurstProgress: ({
          required burstIndex,
          required effectiveBursts,
          required appendedTotal,
          required skippedTotal,
          required decisionsTotal,
          required peakPending,
          required slowChunks,
        }) async {
          progressCalls += 1;
        },
      );

      expect(result.effectiveBursts, 1);
      expect(progressCalls, 1);
      expect(result.cancelled, isFalse);
      expect(result.attemptedTotal, 200);
      expect(result.appendedTotal, 200);
      expect(result.skippedTotal, 0);
      expect(result.decisionsTotal, 0);
    });

    test('tracks duplicate injection and skip counts', () async {
      final service = buildService();

      final result = await service.run(
        profile: const IntakeStressProfile(
          feeds: 2,
          recordsPerFeed: 10,
          bursts: 1,
          highRiskPercent: 0,
          siteSpread: 2,
          maxAttemptedEvents: 1000,
          seed: 42,
          chunkSize: 50,
          duplicatePercent: 20,
          interBurstDelayMs: 0,
          verifyReplay: false,
          stopOnRegression: false,
          regressionThroughputDrop: 20,
          regressionVerifyIncreaseMs: 100,
          maxRegressionPressureSeverity: 2,
          maxRegressionImbalanceSeverity: 2,
          soakRuns: 1,
        ),
        runId: 'STR-DUP',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        primarySiteId: 'SITE-SANDTON',
        shouldCancel: () => false,
        onBurstProgress: ({
          required burstIndex,
          required effectiveBursts,
          required appendedTotal,
          required skippedTotal,
          required decisionsTotal,
          required peakPending,
          required slowChunks,
        }) async {},
      );

      expect(result.effectiveBursts, 1);
      expect(result.duplicatesInjected, 4);
      expect(result.attemptedTotal, 24);
      expect(result.appendedTotal, 20);
      expect(result.skippedTotal, 4);
      expect(result.siteDistribution.values.reduce((a, b) => a + b), 20);
      expect(result.feedDistribution['feed-01'], 10);
      expect(result.feedDistribution['feed-02'], 10);
    });

    test('honors cancellation before processing bursts', () async {
      final service = buildService();
      var progressCalls = 0;

      final result = await service.run(
        profile: const IntakeStressProfile(
          feeds: 2,
          recordsPerFeed: 10,
          bursts: 3,
          highRiskPercent: 0,
          siteSpread: 1,
          maxAttemptedEvents: 1000,
          seed: 42,
          chunkSize: 50,
          duplicatePercent: 0,
          interBurstDelayMs: 0,
          verifyReplay: false,
          stopOnRegression: false,
          regressionThroughputDrop: 20,
          regressionVerifyIncreaseMs: 100,
          maxRegressionPressureSeverity: 2,
          maxRegressionImbalanceSeverity: 2,
          soakRuns: 1,
        ),
        runId: 'STR-CANCEL',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        primarySiteId: 'SITE-SANDTON',
        shouldCancel: () => true,
        onBurstProgress: ({
          required burstIndex,
          required effectiveBursts,
          required appendedTotal,
          required skippedTotal,
          required decisionsTotal,
          required peakPending,
          required slowChunks,
        }) async {
          progressCalls += 1;
        },
      );

      expect(result.cancelled, isTrue);
      expect(progressCalls, 0);
      expect(result.attemptedTotal, 0);
      expect(result.appendedTotal, 0);
      expect(result.skippedTotal, 0);
      expect(result.decisionsTotal, 0);
    });
  });
}
