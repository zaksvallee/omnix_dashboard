import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/zara/allowance_metering.dart';
import 'package:omnix_dashboard/application/zara/capability_registry.dart';

void main() {
  group('resolveZaraAllowancePlan', () {
    test('uses tier defaults when no client override is present', () {
      final plan = resolveZaraAllowancePlan(tier: ZaraAllowanceTier.standard);

      expect(plan.monthlyIncludedUnits, 250);
      expect(plan.sourceLabel, 'tier-default');
    });

    test('uses client metadata override when present', () {
      final plan = resolveZaraAllowancePlan(
        tier: ZaraAllowanceTier.tactical,
        clientMetadata: <String, dynamic>{
          'zara_monthly_allowance_queries': '900',
        },
      );

      expect(plan.monthlyIncludedUnits, 900);
      expect(plan.sourceLabel, 'client-metadata');
    });
  });

  group('zaraAllowanceWarningEventForTransition', () {
    test('triggers the 80 percent warning only on first crossing', () {
      const plan = ZaraAllowancePlan(
        tier: ZaraAllowanceTier.standard,
        monthlyIncludedUnits: 250,
      );
      final beforeUsage = ZaraMonthlyUsageSnapshot(
        periodMonthUtc: DateTime.utc(2026, 5, 1),
        plan: plan,
        usedUnits: 199,
      );
      final afterUsage = ZaraMonthlyUsageSnapshot(
        periodMonthUtc: DateTime.utc(2026, 5, 1),
        plan: plan,
        usedUnits: 200,
      );

      final event = zaraAllowanceWarningEventForTransition(
        beforeUsage: beforeUsage,
        afterUsage: afterUsage,
      );

      expect(event, ZaraAllowanceWarningEvent.warning80);
    });

    test('prioritizes the 100 percent warning when the limit is crossed', () {
      const plan = ZaraAllowancePlan(
        tier: ZaraAllowanceTier.standard,
        monthlyIncludedUnits: 250,
      );
      final beforeUsage = ZaraMonthlyUsageSnapshot(
        periodMonthUtc: DateTime.utc(2026, 5, 1),
        plan: plan,
        usedUnits: 249,
      );
      final afterUsage = ZaraMonthlyUsageSnapshot(
        periodMonthUtc: DateTime.utc(2026, 5, 1),
        plan: plan,
        usedUnits: 250,
      );

      final event = zaraAllowanceWarningEventForTransition(
        beforeUsage: beforeUsage,
        afterUsage: afterUsage,
      );

      expect(event, ZaraAllowanceWarningEvent.warning100);
    });

    test('does not re-warn once the limit was already crossed earlier', () {
      const plan = ZaraAllowancePlan(
        tier: ZaraAllowanceTier.standard,
        monthlyIncludedUnits: 250,
      );
      final beforeUsage = ZaraMonthlyUsageSnapshot(
        periodMonthUtc: DateTime.utc(2026, 5, 1),
        plan: plan,
        usedUnits: 250,
      );
      final afterUsage = ZaraMonthlyUsageSnapshot(
        periodMonthUtc: DateTime.utc(2026, 5, 1),
        plan: plan,
        usedUnits: 251,
      );

      final event = zaraAllowanceWarningEventForTransition(
        beforeUsage: beforeUsage,
        afterUsage: afterUsage,
      );

      expect(event, ZaraAllowanceWarningEvent.none);
    });
  });

  group('buildZaraAllowanceWarningText', () {
    test('mentions emergency continuity at the soft-overage threshold', () {
      const plan = ZaraAllowancePlan(
        tier: ZaraAllowanceTier.standard,
        monthlyIncludedUnits: 250,
      );
      final usage = ZaraMonthlyUsageSnapshot(
        periodMonthUtc: DateTime.utc(2026, 5, 1),
        plan: plan,
        usedUnits: 250,
      );

      final warning = buildZaraAllowanceWarningText(
        event: ZaraAllowanceWarningEvent.warning100,
        usage: usage,
        isEmergency: true,
      );

      expect(warning, contains('no hard cutoff'));
      expect(warning, contains('soft overage'));
    });
  });

  group('zaraBillableUnitsForTurn', () {
    test('counts delegated turns as billable', () {
      expect(
        zaraBillableUnitsForTurn(
          decisionLabel: 'delegated',
          usedFallback: false,
          capabilityKey: 'footfall_count',
        ),
        1,
      );
    });

    test('keeps deterministic fallback turns non-billable', () {
      expect(
        zaraBillableUnitsForTurn(
          decisionLabel: 'fallback',
          usedFallback: true,
          capabilityKey: null,
        ),
        0,
      );
    });
  });
}
