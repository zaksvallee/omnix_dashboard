import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/zara/capability_registry.dart';
import 'package:omnix_dashboard/application/zara/zara_runtime_scope_resolver.dart';

class _FakeZaraRuntimeScopeDataSource implements ZaraRuntimeScopeDataSource {
  Map<String, dynamic>? clientScope;
  ZaraSiteSignals siteSignals;

  _FakeZaraRuntimeScopeDataSource({
    this.clientScope,
    this.siteSignals = const ZaraSiteSignals(
      siteExists: false,
      hasFootfallSignals: false,
      hasFaceRegistryEntries: false,
      hasVehicleAnalyticsSignals: false,
    ),
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
}

void main() {
  group('parseZaraAllowanceTier', () {
    test('parses known allowance tier strings', () {
      expect(
        parseZaraAllowanceTier('standard'),
        ZaraAllowanceTier.standard,
      );
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
  });
}
