import 'dart:developer' as developer;

import 'package:supabase/supabase.dart';

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

  Future<ZaraAllowanceTier> resolveAllowanceTier(String? clientId) async {
    final normalizedClientId = clientId?.trim() ?? '';
    if (normalizedClientId.isEmpty) {
      return ZaraAllowanceTier.standard;
    }

    final row = await dataSource.fetchClientScope(normalizedClientId);
    final metadata = (row?['metadata'] as Map?)?.cast<String, dynamic>();
    final parsedTier =
        parseZaraAllowanceTier(row?['zara_allowance_tier']) ??
        parseZaraAllowanceTier(metadata?['zara_allowance_tier']) ??
        parseZaraAllowanceTier(metadata?['zara_tier']);
    return parsedTier ?? ZaraAllowanceTier.standard;
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
