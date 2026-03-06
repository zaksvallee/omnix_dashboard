import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/guard_telemetry_bridge_writer.dart';
import 'package:omnix_dashboard/application/guard_telemetry_ingestion_adapter.dart';

void main() {
  test('factory returns noop writer when disabled', () {
    final writer = createGuardTelemetryBridgeWriter(
      providerId: 'fsk_sdk',
      enabled: false,
    );
    expect(writer, isA<NoopGuardTelemetryBridgeWriter>());
    expect(writer.isAvailable, isFalse);
  });

  test('method-channel writer writes bridge payload', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('onyx/guard_telemetry_bridge_test_write');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var invoked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'ingestWearableHeartbeatBridge') {
        throw MissingPluginException('Unsupported method ${call.method}');
      }
      invoked = true;
      final args = call.arguments! as Map;
      expect(args['provider_id'], 'fsk_sdk');
      expect(args['heart_rate'], 81);
      expect(args['movement_level'], 0.66);
      expect(args['activity_state'], 'patrolling');
      expect(args['battery_percent'], 88);
      expect(args['source'], 'writer_test');
      expect(args['sdk_status'], 'live');
      expect(args['gps_accuracy_meters'], 3.7);
      return <String, Object?>{'accepted': true};
    });

    final writer = MethodChannelGuardTelemetryBridgeWriter(
      channel: channel,
      providerId: 'fsk_sdk',
      maxAttempts: 1,
      initialBackoff: Duration.zero,
      sleep: (_) async {},
    );
    await writer.writeWearableHeartbeat(
      sample: WearableTelemetrySample(
        heartRate: 81,
        movementLevel: 0.66,
        activityState: 'patrolling',
        batteryPercent: 88,
        capturedAtUtc: DateTime.utc(2026, 3, 5, 11, 0),
        source: 'writer_test',
        providerId: 'fsk_sdk',
        sdkStatus: 'live',
      ),
      gpsAccuracyMeters: 3.7,
    );
    expect(invoked, isTrue);

    messenger.setMockMethodCallHandler(channel, null);
  });

  test('method-channel writer retries on platform exception', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('onyx/guard_telemetry_bridge_test_retry');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var callCount = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      callCount += 1;
      if (callCount < 3) {
        throw PlatformException(code: 'TEMP_FAIL', message: 'try again');
      }
      return <String, Object?>{'accepted': true};
    });

    final writer = MethodChannelGuardTelemetryBridgeWriter(
      channel: channel,
      providerId: 'fsk_sdk',
      maxAttempts: 3,
      initialBackoff: Duration.zero,
      sleep: (_) async {},
    );
    await writer.writeWearableHeartbeat(
      sample: WearableTelemetrySample(
        heartRate: 75,
        movementLevel: 0.58,
        activityState: 'patrolling',
        batteryPercent: 87,
        capturedAtUtc: DateTime.utc(2026, 3, 5, 11, 5),
        source: 'retry_test',
        providerId: 'fsk_sdk',
        sdkStatus: 'live',
      ),
    );
    expect(callCount, 3);

    messenger.setMockMethodCallHandler(channel, null);
  });
}
