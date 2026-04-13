import 'dart:async';

import 'package:supabase/supabase.dart';

enum OnyxPowerMode { normal, degraded, threat }

class OnyxPowerHealthSnapshot {
  final int totalCameraCount;
  final int offlineCameraCount;
  final bool dvrReachable;
  final bool syntheticGuardConfigured;
  final String siteName;

  const OnyxPowerHealthSnapshot({
    required this.totalCameraCount,
    required this.offlineCameraCount,
    required this.dvrReachable,
    this.syntheticGuardConfigured = false,
    this.siteName = '',
  });
}

class OnyxPowerModeChange {
  final OnyxPowerMode mode;
  final String reason;
  final DateTime occurredAt;
  final bool manualOverrideActive;

  const OnyxPowerModeChange({
    required this.mode,
    required this.reason,
    required this.occurredAt,
    this.manualOverrideActive = false,
  });
}

class OnyxPowerModeService {
  final String siteId;
  final SupabaseClient? supabaseClient;
  final Future<OnyxPowerHealthSnapshot> Function() readHealth;
  final Future<void> Function(OnyxPowerModeChange change)? onModeChanged;
  final Duration pollInterval;
  final DateTime Function() clock;

  Timer? _timer;
  OnyxPowerMode _currentMode = OnyxPowerMode.normal;
  String _currentReason = 'Automatic recovery';
  OnyxPowerHealthSnapshot? _lastHealthSnapshot;

  OnyxPowerModeService({
    required this.siteId,
    required this.readHealth,
    this.supabaseClient,
    this.onModeChanged,
    this.pollInterval = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  OnyxPowerMode get currentMode => _currentMode;
  String get currentReason => _currentReason;
  OnyxPowerHealthSnapshot? get lastHealthSnapshot => _lastHealthSnapshot;
  bool get syntheticGuardEnabled =>
      (_lastHealthSnapshot?.syntheticGuardConfigured ?? false) &&
      _currentMode == OnyxPowerMode.threat;

  Future<void> start() async {
    await stop();
    await evaluateNow();
    _timer = Timer.periodic(pollInterval, (_) {
      unawaited(evaluateNow());
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<OnyxPowerModeChange> evaluateNow() async {
    final manualOverride = await _readManualOverride();
    if (manualOverride != null) {
      return _applyMode(
        mode: manualOverride.mode,
        reason: manualOverride.reason,
        persistChange: false,
        manualOverrideActive: true,
      );
    }

    final health = await readHealth();
    _lastHealthSnapshot = health;
    final totalCameraCount = health.totalCameraCount <= 0
        ? 1
        : health.totalCameraCount;
    final offlineRatio = health.offlineCameraCount / totalCameraCount;
    if (!health.dvrReachable) {
      return _applyMode(
        mode: OnyxPowerMode.threat,
        reason:
            'DVR unreachable${health.siteName.trim().isEmpty ? '' : ' at ${health.siteName.trim()}'}',
        persistChange: true,
      );
    }
    if (offlineRatio > 0.5) {
      return _applyMode(
        mode: OnyxPowerMode.degraded,
        reason:
            'Camera health degraded (${health.offlineCameraCount}/$totalCameraCount offline)',
        persistChange: true,
      );
    }
    return _applyMode(
      mode: OnyxPowerMode.normal,
      reason: 'Automatic recovery',
      persistChange: true,
    );
  }

  Future<void> recordManualOverride({
    required OnyxPowerMode? mode,
    required String reason,
  }) async {
    final client = supabaseClient;
    if (client == null) {
      return;
    }
    final normalizedReason = reason.trim().isEmpty
        ? 'manual_override:${mode?.name ?? 'auto'}'
        : reason.trim();
    await client.from('onyx_power_mode_events').insert(<String, Object?>{
      'site_id': siteId.trim(),
      'mode': (mode ?? OnyxPowerMode.normal).name,
      'reason': normalizedReason,
      'occurred_at': clock().toUtc().toIso8601String(),
    });
  }

  Future<({OnyxPowerMode mode, String reason})?> _readManualOverride() async {
    final client = supabaseClient;
    if (client == null) {
      return null;
    }
    try {
      final dynamic row = await client
          .from('onyx_power_mode_events')
          .select('mode,reason,occurred_at')
          .eq('site_id', siteId.trim())
          .order('occurred_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row is! Map<String, dynamic>) {
        return null;
      }
      final reason = (row['reason'] as String? ?? '').trim();
      if (!reason.startsWith('manual_override:')) {
        return null;
      }
      if (reason == 'manual_override:auto') {
        return null;
      }
      final modeLabel = (row['mode'] as String? ?? '').trim().toLowerCase();
      final mode = OnyxPowerMode.values
          .where((candidate) {
            return candidate.name == modeLabel;
          })
          .cast<OnyxPowerMode?>()
          .firstOrNull;
      if (mode == null) {
        return null;
      }
      return (mode: mode, reason: reason);
    } catch (_) {
      return null;
    }
  }

  Future<OnyxPowerModeChange> _applyMode({
    required OnyxPowerMode mode,
    required String reason,
    required bool persistChange,
    bool manualOverrideActive = false,
  }) async {
    final now = clock().toUtc();
    final changed = mode != _currentMode || reason.trim() != _currentReason;
    _currentMode = mode;
    _currentReason = reason.trim();
    final change = OnyxPowerModeChange(
      mode: mode,
      reason: _currentReason,
      occurredAt: now,
      manualOverrideActive: manualOverrideActive,
    );
    if (!changed) {
      return change;
    }
    if (persistChange && supabaseClient != null) {
      await supabaseClient!
          .from('onyx_power_mode_events')
          .insert(<String, Object?>{
            'site_id': siteId.trim(),
            'mode': mode.name,
            'reason': _currentReason,
            'occurred_at': now.toIso8601String(),
          });
    }
    if (onModeChanged != null) {
      await onModeChanged!(change);
    }
    return change;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
