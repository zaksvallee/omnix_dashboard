import 'dart:developer' as developer;

import 'package:supabase/supabase.dart';

import 'allowance_metering.dart';
import 'capability_registry.dart';

class ZaraSiteSignals {
  final bool siteExists;
  final bool hasFootfallSignals;
  final bool hasFaceRegistryEntries;
  final bool hasVehicleAnalyticsSignals;
  final bool hasScenarioSupport;

  const ZaraSiteSignals({
    required this.siteExists,
    required this.hasFootfallSignals,
    required this.hasFaceRegistryEntries,
    required this.hasVehicleAnalyticsSignals,
    this.hasScenarioSupport = false,
  });
}

abstract class ZaraRuntimeScopeDataSource {
  Future<Map<String, dynamic>?> fetchClientScope(String clientId);

  Future<ZaraSiteSignals> fetchSiteSignals({
    String? clientId,
    required String siteId,
  });

  Future<int> fetchMonthlyUsageUnits({
    required String clientId,
    required DateTime periodMonthUtc,
  });

  Future<void> insertUsageLedgerEntry(ZaraUsageLedgerEntry entry);
}

class SupabaseZaraRuntimeScopeDataSource implements ZaraRuntimeScopeDataSource {
  final SupabaseClient supabase;

  const SupabaseZaraRuntimeScopeDataSource({required this.supabase});

  @override
  Future<Map<String, dynamic>?> fetchClientScope(String clientId) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return null;
    }
    try {
      final row = await supabase
          .from('clients')
          .select('client_id, zara_allowance_tier, metadata')
          .eq('client_id', normalizedClientId)
          .maybeSingle();
      if (row != null) {
        return Map<String, dynamic>.from(row);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch Zara client scope for $normalizedClientId.',
        name: 'zara.runtime_scope',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  @override
  Future<ZaraSiteSignals> fetchSiteSignals({
    String? clientId,
    required String siteId,
  }) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const ZaraSiteSignals(
        siteExists: false,
        hasFootfallSignals: false,
        hasFaceRegistryEntries: false,
        hasVehicleAnalyticsSignals: false,
      );
    }

    final siteExistsFuture = _rowExists(
      table: 'sites',
      selectColumn: 'site_id',
      filterColumn: 'site_id',
      filterValue: normalizedSiteId,
    );
    final occupancyConfigFuture = _rowExists(
      table: 'site_occupancy_config',
      selectColumn: 'site_id',
      filterColumn: 'site_id',
      filterValue: normalizedSiteId,
    );
    final occupancySessionsFuture = _rowExists(
      table: 'site_occupancy_sessions',
      selectColumn: 'site_id',
      filterColumn: 'site_id',
      filterValue: normalizedSiteId,
    );
    final vehicleMonitoringFuture = _vehicleMonitoringEnabled(normalizedSiteId);
    final vehicleRegistryFuture = _rowExists(
      table: 'site_vehicle_registry',
      selectColumn: 'site_id',
      filterColumn: 'site_id',
      filterValue: normalizedSiteId,
    );
    final faceRegistryFuture = _rowExists(
      table: 'fr_person_registry',
      selectColumn: 'site_id',
      filterColumn: 'site_id',
      filterValue: normalizedSiteId,
    );

    final results = await Future.wait<bool>(<Future<bool>>[
      siteExistsFuture,
      occupancyConfigFuture,
      occupancySessionsFuture,
      vehicleMonitoringFuture,
      vehicleRegistryFuture,
      faceRegistryFuture,
    ]);

    final siteExists = results[0];
    final hasFootfallSignals = results[1] || results[2];
    final hasVehicleAnalyticsSignals = results[3] || results[4];
    final hasFaceRegistryEntries = results[5];

    return ZaraSiteSignals(
      siteExists: siteExists,
      hasFootfallSignals: hasFootfallSignals,
      hasFaceRegistryEntries: hasFaceRegistryEntries,
      hasVehicleAnalyticsSignals: hasVehicleAnalyticsSignals,
      hasScenarioSupport: false,
    );
  }

  @override
  Future<int> fetchMonthlyUsageUnits({
    required String clientId,
    required DateTime periodMonthUtc,
  }) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return 0;
    }
    try {
      final row = await supabase
          .from('zara_usage_monthly_summary')
          .select('total_units')
          .eq('client_id', normalizedClientId)
          .eq('period_month', _dateValue(periodMonthUtc))
          .maybeSingle();
      return parsePositiveInt(row?['total_units']) ?? 0;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch Zara monthly usage for $normalizedClientId.',
        name: 'zara.runtime_scope',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  @override
  Future<void> insertUsageLedgerEntry(ZaraUsageLedgerEntry entry) async {
    await supabase.from('zara_usage_ledger').insert(entry.toInsertRow());
  }

  Future<bool> _rowExists({
    required String table,
    required String selectColumn,
    required String filterColumn,
    required Object filterValue,
  }) async {
    try {
      final rows = await supabase
          .from(table)
          .select(selectColumn)
          .eq(filterColumn, filterValue)
          .limit(1);
      return rows.isNotEmpty;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to probe $table for Zara runtime signals.',
        name: 'zara.runtime_scope',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> _vehicleMonitoringEnabled(String siteId) async {
    try {
      final row = await supabase
          .from('site_intelligence_profiles')
          .select('monitor_vehicle_movement')
          .eq('site_id', siteId)
          .maybeSingle();
      if (row != null) {
        return row['monitor_vehicle_movement'] == true;
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to probe site vehicle monitoring state for Zara runtime signals.',
        name: 'zara.runtime_scope',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return false;
  }
}

class ZaraRuntimeScopeResolver {
  final ZaraRuntimeScopeDataSource dataSource;

  const ZaraRuntimeScopeResolver({required this.dataSource});

  Future<ZaraAllowancePlan> resolveAllowancePlan(String? clientId) async {
    final normalizedClientId = clientId?.trim() ?? '';
    final clientScope = normalizedClientId.isEmpty
        ? null
        : await dataSource.fetchClientScope(normalizedClientId);
    return _allowancePlanFromScope(clientScope);
  }

  Future<ZaraAllowanceContext> resolveAllowanceContext(
    String? clientId, {
    DateTime? nowUtc,
  }) async {
    final effectiveNowUtc = (nowUtc ?? DateTime.now()).toUtc();
    final plan = await resolveAllowancePlan(clientId);
    final usage = await resolveMonthlyUsage(
      clientId,
      nowUtc: effectiveNowUtc,
      allowancePlan: plan,
    );
    return ZaraAllowanceContext(plan: plan, usage: usage);
  }

  Future<ZaraAllowanceTier> resolveAllowanceTier(String? clientId) async {
    final plan = await resolveAllowancePlan(clientId);
    return plan.tier;
  }

  Future<ZaraMonthlyUsageSnapshot> resolveMonthlyUsage(
    String? clientId, {
    DateTime? nowUtc,
    ZaraAllowancePlan? allowancePlan,
  }) async {
    final effectiveNowUtc = (nowUtc ?? DateTime.now()).toUtc();
    final normalizedClientId = clientId?.trim() ?? '';
    final plan =
        allowancePlan ??
        ZaraAllowancePlan(
          tier: ZaraAllowanceTier.standard,
          monthlyIncludedUnits: defaultMonthlyIncludedUnitsForTier(
            ZaraAllowanceTier.standard,
          ),
        );
    if (normalizedClientId.isEmpty) {
      return ZaraMonthlyUsageSnapshot(
        periodMonthUtc: zaraUsagePeriodMonthUtc(effectiveNowUtc),
        plan: plan,
        usedUnits: 0,
      );
    }

    final usedUnits = await dataSource.fetchMonthlyUsageUnits(
      clientId: normalizedClientId,
      periodMonthUtc: zaraUsagePeriodMonthUtc(effectiveNowUtc),
    );
    return ZaraMonthlyUsageSnapshot(
      periodMonthUtc: zaraUsagePeriodMonthUtc(effectiveNowUtc),
      plan: plan,
      usedUnits: usedUnits,
    );
  }

  Future<void> recordUsageEntry(ZaraUsageLedgerEntry entry) async {
    await dataSource.insertUsageLedgerEntry(entry);
  }

  Future<Set<String>> resolveActiveDataSources(
    String? clientId,
    String? siteId,
  ) async {
    final normalizedSiteId = siteId?.trim() ?? '';
    if (normalizedSiteId.isEmpty) {
      return <String>{};
    }

    final signals = await dataSource.fetchSiteSignals(
      clientId: clientId?.trim(),
      siteId: normalizedSiteId,
    );
    return zaraActiveDataSourcesFromSignals(signals);
  }

  ZaraAllowancePlan _allowancePlanFromScope(Map<String, dynamic>? row) {
    final metadata = (row?['metadata'] as Map?)?.cast<String, dynamic>();
    final parsedTier =
        parseZaraAllowanceTier(row?['zara_allowance_tier']) ??
        parseZaraAllowanceTier(metadata?['zara_allowance_tier']) ??
        parseZaraAllowanceTier(metadata?['zara_tier']) ??
        ZaraAllowanceTier.standard;
    return resolveZaraAllowancePlan(tier: parsedTier, clientMetadata: metadata);
  }
}

Set<String> zaraActiveDataSourcesFromSignals(ZaraSiteSignals signals) {
  if (!signals.siteExists) {
    return <String>{};
  }

  // These sources are part of the baseline ONYX site scope once a site is
  // provisioned, even if a specific site has not accumulated rows yet.
  final activeDataSources = <String>{
    'dispatch_events',
    'incident_notes',
    'shift_instances',
  };

  if (signals.hasFootfallSignals) {
    activeDataSources.add('cv_pipeline_footfall');
  }
  if (signals.hasFaceRegistryEntries) {
    activeDataSources.add('fr_person_registry');
  }
  if (signals.hasVehicleAnalyticsSignals) {
    activeDataSources.add('bi_vehicle_persistence');
  }
  if (signals.hasScenarioSupport) {
    activeDataSources.add('zara_scenarios');
  }

  // report_bundle remains intentionally absent here. The Telegram lane does
  // not yet assemble report bundles at runtime, so exposing it as "active"
  // would overpromise capability availability.
  return activeDataSources;
}

String _dateValue(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-$month-$day';
}
