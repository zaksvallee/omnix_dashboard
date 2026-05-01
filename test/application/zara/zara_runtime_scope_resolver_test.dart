import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/zara/allowance_metering.dart';
import 'package:omnix_dashboard/application/zara/capability_registry.dart';
import 'package:omnix_dashboard/application/zara/zara_runtime_scope_resolver.dart';

class _FakeZaraRuntimeScopeDataSource implements ZaraRuntimeScopeDataSource {
  Map<String, dynamic>? clientScope;
  ZaraSiteSignals siteSignals;
  List<ZaraExplicitDataSourceActivation> explicitDataSourceActivations;
  int monthlyUsageUnits;
  final List<ZaraUsageLedgerEntry> insertedLedgerEntries =
      <ZaraUsageLedgerEntry>[];

  _FakeZaraRuntimeScopeDataSource({
    this.clientScope,
    this.siteSignals = const ZaraSiteSignals(
      siteExists: false,
      hasFootfallSignals: false,
      hasFaceRegistryEntries: false,
      hasVehicleAnalyticsSignals: false,
    ),
    this.explicitDataSourceActivations =
        const <ZaraExplicitDataSourceActivation>[],
    this.monthlyUsageUnits = 0,
  });

  @override
  Future<Map<String, dynamic>?> fetchClientScope(String clientId) async {
    return clientScope;
  }

  @override
  Future<ZaraSiteSignals> fetchSiteSignals({
    String? clientId,
    required String siteId,
  }) async {
    return siteSignals;
  }

  @override
  Future<List<ZaraExplicitDataSourceActivation>>
  fetchExplicitDataSourceActivations({
    required String clientId,
    required String siteId,
  }) async {
    return explicitDataSourceActivations;
  }

  @override
  Future<int> fetchMonthlyUsageUnits({
    required String clientId,
    required DateTime periodMonthUtc,
  }) async {
    return monthlyUsageUnits;
  }

  @override
  Future<void> insertUsageLedgerEntry(ZaraUsageLedgerEntry entry) async {
    insertedLedgerEntries.add(entry);
    monthlyUsageUnits += entry.billableUnits;
  }
}

void main() {
  group('parseZaraAllowanceTier', () {
    test('parses known allowance tier strings', () {
      expect(parseZaraAllowanceTier('standard'), ZaraAllowanceTier.standard);
      expect(parseZaraAllowanceTier('Premium'), ZaraAllowanceTier.premium);
      expect(parseZaraAllowanceTier('TACTICAL'), ZaraAllowanceTier.tactical);
    });

    test('returns null for unknown allowance tier strings', () {
      expect(parseZaraAllowanceTier('gold'), isNull);
      expect(parseZaraAllowanceTier(null), isNull);
      expect(parseZaraAllowanceTier(''), isNull);
    });
  });

  group('ZaraRuntimeScopeResolver', () {
    test('reads explicit zara_allowance_tier column first', () async {
      final dataSource = _FakeZaraRuntimeScopeDataSource(
        clientScope: <String, dynamic>{
          'zara_allowance_tier': 'premium',
          'metadata': <String, dynamic>{
            'zara_allowance_tier': 'tactical',
            'zara_tier': 'standard',
          },
        },
      );
      final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

      final tier = await resolver.resolveAllowanceTier('CLT-001');

      expect(tier, ZaraAllowanceTier.premium);
    });

    test(
      'falls back to metadata zara_allowance_tier when column is absent',
      () async {
        final dataSource = _FakeZaraRuntimeScopeDataSource(
          clientScope: <String, dynamic>{
            'metadata': <String, dynamic>{'zara_allowance_tier': 'tactical'},
          },
        );
        final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

        final tier = await resolver.resolveAllowanceTier('CLT-001');

        expect(tier, ZaraAllowanceTier.tactical);
      },
    );

    test('falls back to legacy metadata zara_tier when needed', () async {
      final dataSource = _FakeZaraRuntimeScopeDataSource(
        clientScope: <String, dynamic>{
          'metadata': <String, dynamic>{'zara_tier': 'premium'},
        },
      );
      final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

      final tier = await resolver.resolveAllowanceTier('CLT-001');

      expect(tier, ZaraAllowanceTier.premium);
    });

    test(
      'falls back to standard when no explicit allowance tier is stored',
      () async {
        final dataSource = _FakeZaraRuntimeScopeDataSource(
          clientScope: <String, dynamic>{
            'metadata': <String, dynamic>{'sla_tier': 'platinum'},
          },
        );
        final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

        final tier = await resolver.resolveAllowanceTier('CLT-001');

        expect(tier, ZaraAllowanceTier.standard);
      },
    );

    test(
      'allowance context uses client metadata override for monthly units',
      () async {
        final dataSource = _FakeZaraRuntimeScopeDataSource(
          clientScope: <String, dynamic>{
            'zara_allowance_tier': 'premium',
            'metadata': <String, dynamic>{
              'zara_monthly_allowance_queries': 750,
            },
          },
          monthlyUsageUnits: 612,
        );
        final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

        final context = await resolver.resolveAllowanceContext(
          'CLT-001',
          nowUtc: DateTime.utc(2026, 5, 1, 12),
        );

        expect(context.plan.tier, ZaraAllowanceTier.premium);
        expect(context.plan.monthlyIncludedUnits, 750);
        expect(context.plan.sourceLabel, 'client-metadata');
        expect(context.usage.usedUnits, 612);
        expect(context.usage.warningThresholdUnits, 600);
      },
    );

    test('returns the active data-source set from live site signals', () async {
      final dataSource = _FakeZaraRuntimeScopeDataSource(
        siteSignals: const ZaraSiteSignals(
          siteExists: true,
          hasFootfallSignals: true,
          hasFaceRegistryEntries: true,
          hasVehicleAnalyticsSignals: true,
        ),
      );
      final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

      final activeDataSources = await resolver.resolveActiveDataSources(
        'CLT-001',
        'SITE-001',
      );

      expect(
        activeDataSources,
        containsAll(<String>[
          'dispatch_events',
          'incident_notes',
          'shift_instances',
          'cv_pipeline_footfall',
          'fr_person_registry',
          'bi_vehicle_persistence',
        ]),
      );
    });

    test('returns an empty set when the site is not scoped', () async {
      final dataSource = _FakeZaraRuntimeScopeDataSource();
      final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

      final activeDataSources = await resolver.resolveActiveDataSources(
        'CLT-001',
        '',
      );

      expect(activeDataSources, isEmpty);
    });

    test(
      'adds explicitly activated sources on top of inferred site signals',
      () async {
        final dataSource = _FakeZaraRuntimeScopeDataSource(
          siteSignals: const ZaraSiteSignals(
            siteExists: true,
            hasFootfallSignals: false,
            hasFaceRegistryEntries: false,
            hasVehicleAnalyticsSignals: false,
          ),
          explicitDataSourceActivations:
              const <ZaraExplicitDataSourceActivation>[
                ZaraExplicitDataSourceActivation(
                  dataSourceKey: 'cv_pipeline_footfall',
                  active: true,
                ),
              ],
        );
        final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

        final activeDataSources = await resolver.resolveActiveDataSources(
          'CLT-001',
          'SITE-001',
        );

        expect(activeDataSources, contains('cv_pipeline_footfall'));
        expect(activeDataSources, contains('dispatch_events'));
      },
    );

    test('explicit inactive activation removes an inferred source', () async {
      final dataSource = _FakeZaraRuntimeScopeDataSource(
        siteSignals: const ZaraSiteSignals(
          siteExists: true,
          hasFootfallSignals: true,
          hasFaceRegistryEntries: false,
          hasVehicleAnalyticsSignals: false,
        ),
        explicitDataSourceActivations: const <ZaraExplicitDataSourceActivation>[
          ZaraExplicitDataSourceActivation(
            dataSourceKey: 'cv_pipeline_footfall',
            active: false,
          ),
        ],
      );
      final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

      final activeDataSources = await resolver.resolveActiveDataSources(
        'CLT-001',
        'SITE-001',
      );

      expect(activeDataSources, isNot(contains('cv_pipeline_footfall')));
      expect(activeDataSources, contains('dispatch_events'));
    });

    test(
      'sources without explicit rows still fall back to inference',
      () async {
        final dataSource = _FakeZaraRuntimeScopeDataSource(
          siteSignals: const ZaraSiteSignals(
            siteExists: true,
            hasFootfallSignals: true,
            hasFaceRegistryEntries: true,
            hasVehicleAnalyticsSignals: true,
          ),
          explicitDataSourceActivations:
              const <ZaraExplicitDataSourceActivation>[
                ZaraExplicitDataSourceActivation(
                  dataSourceKey: 'cv_pipeline_footfall',
                  active: false,
                ),
              ],
        );
        final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);

        final activeDataSources = await resolver.resolveActiveDataSources(
          'CLT-001',
          'SITE-001',
        );

        expect(activeDataSources, isNot(contains('cv_pipeline_footfall')));
        expect(activeDataSources, contains('fr_person_registry'));
        expect(activeDataSources, contains('bi_vehicle_persistence'));
      },
    );

    test('records Zara usage ledger entries through the data source', () async {
      final dataSource = _FakeZaraRuntimeScopeDataSource();
      final resolver = ZaraRuntimeScopeResolver(dataSource: dataSource);
      final entry = ZaraUsageLedgerEntry(
        clientId: 'CLT-001',
        siteId: 'SITE-001',
        audienceLabel: 'client',
        deliveryModeLabel: 'telegramLive',
        allowanceTier: ZaraAllowanceTier.standard,
        capabilityKey: 'footfall_count',
        decisionLabel: 'delegated',
        providerLabel: 'openai:gpt-5.4',
        usedFallback: false,
        isEmergency: false,
        billableUnits: 1,
        createdAtUtc: DateTime.utc(2026, 5, 1, 12),
      );

      await resolver.recordUsageEntry(entry);
      final usage = await resolver.resolveMonthlyUsage(
        'CLT-001',
        nowUtc: DateTime.utc(2026, 5, 1, 12),
        allowancePlan: const ZaraAllowancePlan(
          tier: ZaraAllowanceTier.standard,
          monthlyIncludedUnits: 250,
        ),
      );

      expect(dataSource.insertedLedgerEntries, hasLength(1));
      expect(dataSource.insertedLedgerEntries.single.billableUnits, 1);
      expect(usage.usedUnits, 1);
    });
  });
}
