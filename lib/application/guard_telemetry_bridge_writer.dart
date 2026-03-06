import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'guard_telemetry_ingestion_adapter.dart';

abstract class GuardTelemetryBridgeWriter {
  bool get isAvailable;
  String get providerId;

  Future<void> writeWearableHeartbeat({
    required WearableTelemetrySample sample,
    double? gpsAccuracyMeters,
  });
}

class NoopGuardTelemetryBridgeWriter implements GuardTelemetryBridgeWriter {
  @override
  final String providerId;

  const NoopGuardTelemetryBridgeWriter({required this.providerId});

  @override
  bool get isAvailable => false;

  @override
  Future<void> writeWearableHeartbeat({
    required WearableTelemetrySample sample,
    double? gpsAccuracyMeters,
  }) async {}
}

class MethodChannelGuardTelemetryBridgeWriter
    implements GuardTelemetryBridgeWriter {
  final MethodChannel channel;
  final String methodName;
  final int maxAttempts;
  final Duration initialBackoff;
  final Future<void> Function(Duration) _sleep;

  @override
  final String providerId;

  const MethodChannelGuardTelemetryBridgeWriter({
    this.channel = const MethodChannel('onyx/guard_telemetry'),
    this.methodName = 'ingestWearableHeartbeatBridge',
    required this.providerId,
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 250),
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? Future.delayed;

  @override
  bool get isAvailable => !kIsWeb && providerId.trim().isNotEmpty;

  @override
  Future<void> writeWearableHeartbeat({
    required WearableTelemetrySample sample,
    double? gpsAccuracyMeters,
  }) async {
    if (!isAvailable) {
      return;
    }
    final attempts = max(1, maxAttempts);
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = await channel
            .invokeMapMethod<String, Object?>(methodName, <String, Object?>{
              'provider_id': providerId,
              'heart_rate': sample.heartRate,
              'movement_level': sample.movementLevel,
              'activity_state': sample.activityState,
              'battery_percent': sample.batteryPercent,
              'captured_at_utc': sample.capturedAtUtc.toUtc().toIso8601String(),
              'source': sample.source,
              'sdk_status': sample.sdkStatus ?? 'live',
              'gps_accuracy_meters': gpsAccuracyMeters,
            });
        if (response == null) {
          throw StateError('Bridge ingest returned empty response.');
        }
        final accepted = response['accepted'];
        if (accepted == false) {
          throw StateError(
            'Bridge ingest rejected payload for provider $providerId.',
          );
        }
        return;
      } on MissingPluginException catch (error) {
        throw StateError(
          'Bridge ingest channel unavailable for provider $providerId: $error',
        );
      } on PlatformException catch (error) {
        lastError = error;
      } catch (error) {
        lastError = error;
      }
      if (attempt < attempts) {
        final delayMs = initialBackoff.inMilliseconds * (1 << (attempt - 1));
        await _sleep(Duration(milliseconds: delayMs));
      }
    }
    throw StateError(
      'Bridge ingest failed after $attempts attempts for provider $providerId: $lastError',
    );
  }
}

GuardTelemetryBridgeWriter createGuardTelemetryBridgeWriter({
  required String providerId,
  bool enabled = true,
  MethodChannel channel = const MethodChannel('onyx/guard_telemetry'),
  String methodName = 'ingestWearableHeartbeatBridge',
  int maxAttempts = 3,
  Duration initialBackoff = const Duration(milliseconds: 250),
  Future<void> Function(Duration)? sleep,
}) {
  if (!enabled) {
    return NoopGuardTelemetryBridgeWriter(providerId: providerId);
  }
  return MethodChannelGuardTelemetryBridgeWriter(
    channel: channel,
    methodName: methodName,
    providerId: providerId,
    maxAttempts: maxAttempts,
    initialBackoff: initialBackoff,
    sleep: sleep,
  );
}
