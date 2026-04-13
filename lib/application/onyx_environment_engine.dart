import 'package:omnix_dashboard/application/onyx_awareness_latency_service.dart';
import 'package:omnix_dashboard/application/onyx_outcome_feedback_service.dart';
import 'package:omnix_dashboard/application/onyx_power_mode_service.dart';

class OnyxEnvironmentContext {
  final OnyxPowerMode powerMode;
  final double adaptedThreshold;
  final Map<String, double> activeZoneOverrides;
  final bool syntheticGuardEnabled;
  final DateTime lastAdaptedAt;

  const OnyxEnvironmentContext({
    required this.powerMode,
    required this.adaptedThreshold,
    required this.activeZoneOverrides,
    required this.syntheticGuardEnabled,
    required this.lastAdaptedAt,
  });
}

class OnyxEnvironmentThresholdDecision {
  final double baseThreshold;
  final double powerAdjustment;
  final double zoneAdjustment;
  final double adaptedThreshold;
  final OnyxPowerMode powerMode;
  final DateTime lastAdaptedAt;
  final Map<String, double> activeZoneOverrides;
  final bool syntheticGuardEnabled;

  const OnyxEnvironmentThresholdDecision({
    required this.baseThreshold,
    required this.powerAdjustment,
    required this.zoneAdjustment,
    required this.adaptedThreshold,
    required this.powerMode,
    required this.lastAdaptedAt,
    required this.activeZoneOverrides,
    required this.syntheticGuardEnabled,
  });

  OnyxEnvironmentContext toContext() {
    return OnyxEnvironmentContext(
      powerMode: powerMode,
      adaptedThreshold: adaptedThreshold,
      activeZoneOverrides: activeZoneOverrides,
      syntheticGuardEnabled: syntheticGuardEnabled,
      lastAdaptedAt: lastAdaptedAt,
    );
  }
}

class OnyxEnvironmentEngine {
  final OnyxPowerModeService powerModeService;
  final OnyxOutcomeFeedbackService outcomeFeedbackService;
  final OnyxAwarenessLatencyService awarenessLatencyService;
  final DateTime Function() _clock;
  final Duration _cacheTtl;

  final Map<String, _CachedEnvironmentContext> _contextCache =
      <String, _CachedEnvironmentContext>{};

  OnyxEnvironmentEngine({
    required this.powerModeService,
    required this.outcomeFeedbackService,
    required this.awarenessLatencyService,
    DateTime Function()? clock,
    Duration cacheTtl = const Duration(minutes: 1),
  }) : _clock = clock ?? DateTime.now,
       _cacheTtl = cacheTtl;

  Future<double> getAdaptedThreshold(String siteId, String zoneId) async {
    final decision = await getThresholdDecision(siteId, zoneId);
    return decision.adaptedThreshold;
  }

  Future<OnyxEnvironmentContext> getCurrentContext(String siteId) async {
    final decision = await getThresholdDecision(siteId, '');
    return decision.toContext();
  }

  Future<OnyxEnvironmentThresholdDecision> getThresholdDecision(
    String siteId,
    String zoneId,
  ) async {
    final normalizedSiteId = siteId.trim();
    final normalizedZoneId = zoneId.trim();
    final cached = _contextCache[normalizedSiteId];
    final nowUtc = _clock().toUtc();
    if (cached != null && nowUtc.difference(cached.cachedAtUtc) <= _cacheTtl) {
      return _decisionForContext(cached.context, normalizedZoneId);
    }
    final context = await _buildContext(normalizedSiteId);
    _contextCache[normalizedSiteId] = _CachedEnvironmentContext(
      context: context,
      cachedAtUtc: nowUtc,
    );
    return _decisionForContext(context, normalizedZoneId);
  }

  Future<OnyxEnvironmentContext> _buildContext(String siteId) async {
    final powerMode = await _readPowerMode(siteId);
    final powerAdjustment = _powerAdjustment(powerMode);
    final accuracy = await outcomeFeedbackService.getSignalAccuracy(siteId);
    final latencyStats = await awarenessLatencyService.getSiteStats(siteId);
    final zoneAdjustments = _zoneAdjustments(accuracy);
    final activeZoneOverrides = <String, double>{};
    for (final entry in zoneAdjustments.entries) {
      activeZoneOverrides[entry.key] = _clampThreshold(
        0.55 + powerAdjustment + entry.value,
      );
    }
    final adaptedThreshold = _clampThreshold(0.55 + powerAdjustment);
    final lastAdaptedAt = latencyStats.alertCount >= 0
        ? _clock().toUtc()
        : _clock().toUtc();
    return OnyxEnvironmentContext(
      powerMode: powerMode,
      adaptedThreshold: adaptedThreshold,
      activeZoneOverrides: Map<String, double>.unmodifiable(
        activeZoneOverrides,
      ),
      syntheticGuardEnabled: powerModeService.syntheticGuardEnabled,
      lastAdaptedAt: lastAdaptedAt,
    );
  }

  OnyxEnvironmentThresholdDecision _decisionForContext(
    OnyxEnvironmentContext context,
    String zoneId,
  ) {
    final baseThreshold = 0.55;
    final powerAdjustment = _powerAdjustment(context.powerMode);
    final zoneOverride = context.activeZoneOverrides[zoneId];
    final double zoneAdjustment = zoneOverride == null
        ? 0
        : zoneOverride - (baseThreshold + powerAdjustment);
    return OnyxEnvironmentThresholdDecision(
      baseThreshold: baseThreshold,
      powerAdjustment: powerAdjustment,
      zoneAdjustment: zoneAdjustment,
      adaptedThreshold: zoneOverride ?? context.adaptedThreshold,
      powerMode: context.powerMode,
      lastAdaptedAt: context.lastAdaptedAt,
      activeZoneOverrides: context.activeZoneOverrides,
      syntheticGuardEnabled: context.syntheticGuardEnabled,
    );
  }

  Map<String, double> _zoneAdjustments(OnyxSignalAccuracySnapshot snapshot) {
    final adjustments = <String, List<double>>{};
    for (final entry in snapshot.zoneBreakdown) {
      adjustments
          .putIfAbsent(entry.zoneId.trim(), () => <double>[])
          .add(entry.recommendedThresholdAdjustment);
    }
    return adjustments.map((zoneId, values) {
      final average = values.reduce((a, b) => a + b) / values.length;
      return MapEntry(zoneId, average);
    });
  }

  Future<OnyxPowerMode> _readPowerMode(String siteId) async {
    final client = powerModeService.supabaseClient;
    if (client != null && siteId.trim().isNotEmpty) {
      try {
        final dynamic row = await client
            .from('onyx_power_mode_events')
            .select('mode')
            .eq('site_id', siteId.trim())
            .order('occurred_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (row is Map<String, dynamic>) {
          final modeLabel = (row['mode'] ?? '').toString().trim().toLowerCase();
          for (final mode in OnyxPowerMode.values) {
            if (mode.name == modeLabel) {
              return mode;
            }
          }
        }
      } catch (_) {
        // Fall back to the live power mode snapshot when the persisted row is unavailable.
      }
    }
    return powerModeService.currentMode;
  }

  double _powerAdjustment(OnyxPowerMode mode) {
    return switch (mode) {
      OnyxPowerMode.normal => 0.0,
      OnyxPowerMode.degraded => -0.10,
      OnyxPowerMode.threat => -0.15,
    };
  }

  double _clampThreshold(double value) {
    if (value < 0.35) {
      return 0.35;
    }
    if (value > 0.80) {
      return 0.80;
    }
    return double.parse(value.toStringAsFixed(2));
  }
}

class _CachedEnvironmentContext {
  final OnyxEnvironmentContext context;
  final DateTime cachedAtUtc;

  const _CachedEnvironmentContext({
    required this.context,
    required this.cachedAtUtc,
  });
}
