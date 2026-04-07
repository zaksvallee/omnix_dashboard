import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/guard_telemetry_ingestion_adapter.dart';

class _ClosableHttpClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream<List<int>>.empty(), 200);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  test('demo adapter emits wearable heartbeat sample', () async {
    final adapter = DemoGuardTelemetryIngestionAdapter(
      random: Random(7),
      clock: () => DateTime.utc(2026, 3, 5, 9, 0),
    );

    final sample = await adapter.captureWearableHeartbeat();
    expect(sample.heartRate, inInclusiveRange(66, 89));
    expect(sample.movementLevel, inInclusiveRange(0.05, 1.2));
    expect(sample.activityState, isNotEmpty);
    expect(sample.batteryPercent, inInclusiveRange(30, 99));
    expect(sample.capturedAtUtc, DateTime.utc(2026, 3, 5, 9, 0));
    expect(sample.source, 'demo_wearable_adapter');
    expect(sample.providerId, 'demo_fallback');
    expect(sample.sdkStatus, 'stub');
    expect(adapter.adapterLabel, 'demo_fallback');
    expect(adapter.isStub, isTrue);
    final status = await adapter.getStatus();
    expect(status.readiness, GuardTelemetryAdapterReadiness.degraded);
    expect(status.isStub, isTrue);
  });

  test('demo adapter emits device health sample', () async {
    final adapter = DemoGuardTelemetryIngestionAdapter(
      random: Random(9),
      clock: () => DateTime.utc(2026, 3, 5, 9, 5),
    );

    final sample = await adapter.captureDeviceHealth();
    expect(sample.batteryPercent, inInclusiveRange(28, 100));
    expect(sample.gpsAccuracyMeters, inInclusiveRange(2.0, 15.0));
    expect(sample.storageAvailableMb, inInclusiveRange(1200, 7999));
    expect(sample.networkState, isNotEmpty);
    expect(sample.deviceTemperatureC, inInclusiveRange(30.0, 39.0));
    expect(sample.capturedAtUtc, DateTime.utc(2026, 3, 5, 9, 5));
    expect(sample.source, 'demo_device_health_adapter');
    expect(sample.providerId, 'demo_fallback');
    expect(sample.sdkStatus, 'stub');
    expect(adapter.adapterLabel, 'demo_fallback');
    expect(adapter.isStub, isTrue);
  });

  test('factory returns demo adapter when URLs are not configured', () {
    final adapter = createGuardTelemetryIngestionAdapter(
      wearableHeartbeatUrl: '',
      deviceHealthUrl: '',
    );
    expect(adapter, isA<DemoGuardTelemetryIngestionAdapter>());
  });

  test('factory returns http adapter when URLs are configured', () {
    final adapter = createGuardTelemetryIngestionAdapter(
      wearableHeartbeatUrl: 'https://wearable.example.com/heartbeat',
      deviceHealthUrl: 'https://device.example.com/health',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(adapter, isA<HttpGuardTelemetryIngestionAdapter>());
    expect(adapter.adapterLabel, 'http_connector');
    expect(adapter.isStub, isFalse);
  });

  test('http adapter reports ready status', () async {
    final adapter = HttpGuardTelemetryIngestionAdapter(
      config: GuardTelemetryHttpConfig(
        wearableHeartbeatUri: Uri.parse('https://wearable.example.com/hb'),
        deviceHealthUri: Uri.parse('https://device.example.com/health'),
      ),
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    final status = await adapter.getStatus();
    expect(status.readiness, GuardTelemetryAdapterReadiness.ready);
    expect(status.isStub, isFalse);
    expect(status.adapterLabel, 'http_connector');
  });

  test('http adapter closes owned client on dispose', () {
    final client = _ClosableHttpClient();
    final adapter = HttpGuardTelemetryIngestionAdapter(
      config: GuardTelemetryHttpConfig(
        wearableHeartbeatUri: Uri.parse('https://wearable.example.com/hb'),
        deviceHealthUri: Uri.parse('https://device.example.com/health'),
      ),
      client: client,
      ownsClient: true,
    );

    adapter.dispose();

    expect(client.closed, isTrue);
  });

  test('http adapter leaves injected client open when not owned', () {
    final client = _ClosableHttpClient();
    final adapter = HttpGuardTelemetryIngestionAdapter(
      config: GuardTelemetryHttpConfig(
        wearableHeartbeatUri: Uri.parse('https://wearable.example.com/hb'),
        deviceHealthUri: Uri.parse('https://device.example.com/health'),
      ),
      client: client,
    );

    adapter.dispose();

    expect(client.closed, isFalse);
  });

  test('factory returns native adapter when native sdk is preferred', () {
    final adapter = createGuardTelemetryIngestionAdapter(
      wearableHeartbeatUrl: '',
      deviceHealthUrl: '',
      preferNativeSdk: true,
      nativeSdkConfig: const GuardTelemetryNativeSdkConfig(
        channel: MethodChannel('onyx/guard_telemetry_test_factory'),
        providerId: 'fsk_sdk',
        stubMode: false,
      ),
    );
    expect(adapter, isA<NativeGuardTelemetryIngestionAdapter>());
    expect(adapter.adapterLabel, 'native_sdk:fsk_sdk');
    expect(adapter.isStub, isFalse);
  });

  test('http adapter parses wearable and device payloads', () async {
    final adapter = HttpGuardTelemetryIngestionAdapter(
      config: GuardTelemetryHttpConfig(
        wearableHeartbeatUri: Uri.parse('https://wearable.example.com/hb'),
        deviceHealthUri: Uri.parse('https://device.example.com/health'),
        bearerToken: 'test-token',
      ),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/hb')) {
          expect(request.headers['authorization'], 'Bearer test-token');
          return http.Response(
            jsonEncode({
              'heart_rate': 74,
              'movement_level': 0.83,
              'activity_state': 'patrolling',
              'battery_percent': 88,
              'captured_at_utc': '2026-03-05T09:10:00Z',
              'source': 'wearable_sdk',
              'provider_id': 'fsk_sdk',
              'sdk_status': 'live',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'battery_percent': 67,
            'gps_accuracy_meters': 3.4,
            'storage_available_mb': 4200,
            'network_state': '4G',
            'device_temperature_c': 34.9,
            'captured_at_utc': '2026-03-05T09:11:00Z',
            'source': 'device_sdk',
            'provider_id': 'fsk_sdk',
            'sdk_status': 'live',
          }),
          200,
        );
      }),
    );

    final wearable = await adapter.captureWearableHeartbeat();
    expect(wearable.heartRate, 74);
    expect(wearable.movementLevel, 0.83);
    expect(wearable.activityState, 'patrolling');
    expect(wearable.batteryPercent, 88);
    expect(wearable.source, 'wearable_sdk');
    expect(wearable.providerId, 'fsk_sdk');
    expect(wearable.sdkStatus, 'live');
    expect(wearable.capturedAtUtc, DateTime.utc(2026, 3, 5, 9, 10));

    final device = await adapter.captureDeviceHealth();
    expect(device.batteryPercent, 67);
    expect(device.gpsAccuracyMeters, 3.4);
    expect(device.storageAvailableMb, 4200);
    expect(device.networkState, '4G');
    expect(device.deviceTemperatureC, 34.9);
    expect(device.source, 'device_sdk');
    expect(device.providerId, 'fsk_sdk');
    expect(device.sdkStatus, 'live');
    expect(device.capturedAtUtc, DateTime.utc(2026, 3, 5, 9, 11));
    expect(adapter.adapterLabel, 'http_connector');
    expect(adapter.isStub, isFalse);
  });

  test('native adapter parses wearable and device payloads', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('onyx/guard_telemetry_test_native');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments, isA<Map>());
      final args = call.arguments! as Map;
      expect(args['provider_id'], 'fsk_sdk');
      if (call.method == 'captureWearableHeartbeat') {
        return <String, Object?>{
          'heart_rate': 79,
          'movement_level': 0.72,
          'activity_state': 'patrolling',
          'battery_percent': 91,
          'captured_at_utc': '2026-03-05T10:00:00Z',
          'source': 'native_wearable_sdk',
          'provider_id': 'fsk_sdk',
          'sdk_status': 'live',
        };
      }
      if (call.method == 'captureDeviceHealth') {
        return <String, Object?>{
          'battery_percent': 81,
          'gps_accuracy_meters': 5.1,
          'storage_available_mb': 3072,
          'network_state': '5G',
          'device_temperature_c': 34.3,
          'captured_at_utc': '2026-03-05T10:01:00Z',
          'source': 'native_device_sdk',
          'provider_id': 'fsk_sdk',
          'sdk_status': 'live',
        };
      }
      if (call.method == 'getTelemetryProviderStatus') {
        return <String, Object?>{
          'readiness': 'ready',
          'message': 'Native provider connected.',
          'provider_id': 'fsk_sdk',
          'sdk_status': 'live',
        };
      }
      throw MissingPluginException('Unsupported method ${call.method}');
    });

    final adapter = NativeGuardTelemetryIngestionAdapter(
      config: const GuardTelemetryNativeSdkConfig(
        channel: channel,
        providerId: 'fsk_sdk',
        stubMode: false,
      ),
    );
    final wearable = await adapter.captureWearableHeartbeat();
    expect(wearable.heartRate, 79);
    expect(wearable.movementLevel, 0.72);
    expect(wearable.activityState, 'patrolling');
    expect(wearable.batteryPercent, 91);
    expect(wearable.source, 'native_wearable_sdk');
    expect(wearable.providerId, 'fsk_sdk');
    expect(wearable.sdkStatus, 'live');
    expect(wearable.capturedAtUtc, DateTime.utc(2026, 3, 5, 10, 0));

    final device = await adapter.captureDeviceHealth();
    expect(device.batteryPercent, 81);
    expect(device.gpsAccuracyMeters, 5.1);
    expect(device.storageAvailableMb, 3072);
    expect(device.networkState, '5G');
    expect(device.deviceTemperatureC, 34.3);
    expect(device.source, 'native_device_sdk');
    expect(device.providerId, 'fsk_sdk');
    expect(device.sdkStatus, 'live');
    expect(device.capturedAtUtc, DateTime.utc(2026, 3, 5, 10, 1));
    expect(adapter.adapterLabel, 'native_sdk:fsk_sdk');
    expect(adapter.isStub, isFalse);
    final status = await adapter.getStatus();
    expect(status.readiness, GuardTelemetryAdapterReadiness.ready);
    expect(status.message, 'Native provider connected.');
    expect(status.providerId, 'fsk_sdk');
    expect(status.isStub, isFalse);

    messenger.setMockMethodCallHandler(channel, null);
  });

  test('native adapter maps error readiness from provider status', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('onyx/guard_telemetry_test_native_error');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getTelemetryProviderStatus') {
        return <String, Object?>{
          'readiness': 'error',
          'message': 'No telemetry provider registered for unknown_provider.',
          'provider_id': 'unknown_provider',
          'sdk_status': 'error',
        };
      }
      if (call.method == 'listTelemetryProviders') {
        return <String, Object?>{
          'available_provider_ids': <String>[
            'android_native_sdk_stub',
            'hikvision_sdk',
            'hikvision_sdk_stub',
            'fsk_sdk',
            'fsk_sdk_stub',
          ],
        };
      }
      throw MissingPluginException('Unsupported method ${call.method}');
    });

    final adapter = NativeGuardTelemetryIngestionAdapter(
      config: const GuardTelemetryNativeSdkConfig(
        channel: channel,
        providerId: 'unknown_provider',
        stubMode: false,
      ),
    );
    final status = await adapter.getStatus();
    expect(status.readiness, GuardTelemetryAdapterReadiness.error);
    expect(
      status.message,
      'No telemetry provider registered for unknown_provider. Available providers: android_native_sdk_stub, hikvision_sdk, hikvision_sdk_stub, fsk_sdk, fsk_sdk_stub.',
    );
    expect(status.adapterLabel, 'native_sdk:unknown_provider');
    expect(status.isStub, isFalse);

    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'native adapter appends provider catalog when status probe throws',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel(
        'onyx/guard_telemetry_test_native_status_exception',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getTelemetryProviderStatus') {
          throw PlatformException(
            code: 'UNKNOWN_PROVIDER',
            message:
                'No telemetry provider is registered for provider_id=fsk_typo',
          );
        }
        if (call.method == 'listTelemetryProviders') {
          return <String, Object?>{
            'available_provider_ids': <String>[
              'android_native_sdk_stub',
              'hikvision_sdk',
              'hikvision_sdk_stub',
              'fsk_sdk',
              'fsk_sdk_stub',
            ],
          };
        }
        throw MissingPluginException('Unsupported method ${call.method}');
      });

      final adapter = NativeGuardTelemetryIngestionAdapter(
        config: const GuardTelemetryNativeSdkConfig(
          channel: channel,
          providerId: 'fsk_typo',
          stubMode: false,
        ),
      );
      final status = await adapter.getStatus();

      expect(status.readiness, GuardTelemetryAdapterReadiness.error);
      expect(status.message, contains('Native telemetry status probe failed:'));
      expect(
        status.message,
        contains(
          'Available providers: android_native_sdk_stub, hikvision_sdk, hikvision_sdk_stub, fsk_sdk, fsk_sdk_stub.',
        ),
      );
      expect(status.adapterLabel, 'native_sdk:fsk_typo');
      expect(status.isStub, isFalse);

      messenger.setMockMethodCallHandler(channel, null);
    },
  );

  test('native adapter status includes facade metadata when present', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('onyx/guard_telemetry_test_native_facade');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getTelemetryProviderStatus') {
        return <String, Object?>{
          'readiness': 'ready',
          'message': 'Native provider connected.',
          'provider_id': 'fsk_sdk',
          'sdk_status': 'live',
          'facade_id': 'fsk_sdk_facade_live',
          'facade_live_mode': true,
          'facade_toggle_source': 'build_config',
          'fsk_vendor_connector': 'broadcast_intent_connector',
          'fsk_vendor_connector_source': 'platform_default',
          'fsk_vendor_connector_error':
              'Failed to initialize vendor connector com.onyx.vendor.MissingConnector.',
          'fsk_vendor_connector_fallback_active': true,
          'facade_callback_error_count': 2,
          'facade_last_callback_error_at_utc': '2026-03-05T10:12:00Z',
          'facade_last_callback_error_message':
              'SDK callback rejected: captured_at_utc is invalid ISO-8601',
        };
      }
      throw MissingPluginException('Unsupported method ${call.method}');
    });

    final adapter = NativeGuardTelemetryIngestionAdapter(
      config: const GuardTelemetryNativeSdkConfig(
        channel: channel,
        providerId: 'fsk_sdk',
        stubMode: false,
      ),
    );
    final status = await adapter.getStatus();
    expect(status.readiness, GuardTelemetryAdapterReadiness.ready);
    expect(status.message, contains('Native provider connected.'));
    expect(
      status.message,
      contains(
        'Vendor connector warning: Failed to initialize vendor connector com.onyx.vendor.MissingConnector.',
      ),
    );
    expect(status.facadeId, 'fsk_sdk_facade_live');
    expect(status.facadeLiveMode, isTrue);
    expect(status.facadeToggleSource, 'build_config');
    expect(status.vendorConnectorId, 'broadcast_intent_connector');
    expect(status.vendorConnectorSource, 'platform_default');
    expect(status.vendorConnectorFallbackActive, isTrue);
    expect(
      status.vendorConnectorErrorMessage,
      'Failed to initialize vendor connector com.onyx.vendor.MissingConnector.',
    );
    expect(status.facadeCallbackErrorCount, 2);
    expect(
      status.facadeLastCallbackErrorAtUtc,
      DateTime.utc(2026, 3, 5, 10, 12),
    );
    expect(
      status.facadeLastCallbackErrorMessage,
      'SDK callback rejected: captured_at_utc is invalid ISO-8601',
    );

    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'native adapter status includes payload adapter hint when available',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel(
        'onyx/guard_telemetry_test_native_payload_adapter',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getTelemetryProviderStatus') {
          return <String, Object?>{
            'readiness': 'ready',
            'message': 'Native provider connected.',
            'provider_id': 'fsk_sdk',
            'sdk_status': 'live',
            'fsk_payload_adapter': 'legacy_ptt',
            'fsk_payload_adapter_source': 'manifest_meta_data',
          };
        }
        throw MissingPluginException('Unsupported method ${call.method}');
      });

      final adapter = NativeGuardTelemetryIngestionAdapter(
        config: const GuardTelemetryNativeSdkConfig(
          channel: channel,
          providerId: 'fsk_sdk',
          stubMode: false,
        ),
      );
      final status = await adapter.getStatus();
      expect(status.readiness, GuardTelemetryAdapterReadiness.ready);
      expect(
        status.message,
        'Native provider connected. Payload adapter: legacy_ptt (manifest_meta_data).',
      );

      messenger.setMockMethodCallHandler(channel, null);
    },
  );

  test('native adapter ingests wearable bridge payload', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('onyx/guard_telemetry_test_native_ingest');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var invoked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'ingestWearableHeartbeatBridge') {
        invoked = true;
        final args = call.arguments! as Map;
        expect(args['provider_id'], 'fsk_sdk');
        expect(args['heart_rate'], 82);
        expect(args['movement_level'], 0.61);
        expect(args['activity_state'], 'patrolling');
        expect(args['battery_percent'], 90);
        expect(args['source'], 'manual_seed');
        expect(args['sdk_status'], 'live');
        expect(args['gps_accuracy_meters'], 3.9);
        return <String, Object?>{'accepted': true};
      }
      throw MissingPluginException('Unsupported method ${call.method}');
    });

    final adapter = NativeGuardTelemetryIngestionAdapter(
      config: const GuardTelemetryNativeSdkConfig(
        channel: channel,
        providerId: 'fsk_sdk',
        stubMode: false,
      ),
    );
    await adapter.ingestWearableHeartbeatBridge(
      sample: WearableTelemetrySample(
        heartRate: 82,
        movementLevel: 0.61,
        activityState: 'patrolling',
        batteryPercent: 90,
        capturedAtUtc: DateTime.utc(2026, 3, 5, 10, 10),
        source: 'manual_seed',
        providerId: 'fsk_sdk',
        sdkStatus: 'live',
      ),
      gpsAccuracyMeters: 3.9,
    );
    expect(invoked, isTrue);

    messenger.setMockMethodCallHandler(channel, null);
  });

  test('native adapter validates FSK payload mapping', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('onyx/guard_telemetry_test_native_validate');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'validateFskPayloadMapping') {
        final args = call.arguments! as Map;
        expect(args['provider_id'], 'fsk_sdk');
        expect(args['payload_adapter'], 'legacy_ptt');
        final payload = args['payload'] as Map;
        expect(payload['pulse'], 81);
        expect(payload['motion_score'], 0.57);
        return <String, Object?>{
          'accepted': true,
          'adapter_requested': 'legacy_ptt',
          'adapter_resolved': 'legacy_ptt',
          'normalized_payload': <String, Object?>{
            'heart_rate': 81,
            'movement_level': 0.57,
            'activity_state': 'patrolling',
            'captured_at_utc': '2026-03-05T14:05:00Z',
          },
        };
      }
      throw MissingPluginException('Unsupported method ${call.method}');
    });

    final adapter = NativeGuardTelemetryIngestionAdapter(
      config: const GuardTelemetryNativeSdkConfig(
        channel: channel,
        providerId: 'fsk_sdk',
        stubMode: false,
      ),
    );

    final response = await adapter.validatePayloadMapping(
      payload: const <String, Object?>{
        'pulse': 81,
        'motion_score': 0.57,
        'state': 'patrolling',
        'time_utc': '2026-03-05T14:05:00Z',
      },
      payloadAdapter: 'legacy_ptt',
    );

    expect(response['accepted'], true);
    expect(response['adapter_requested'], 'legacy_ptt');
    expect(response['adapter_resolved'], 'legacy_ptt');
    final normalized = response['normalized_payload'] as Map;
    expect(normalized['heart_rate'], 81);
    expect(normalized['movement_level'], 0.57);

    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'native adapter validates Hikvision payload mapping with provider-specific method',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel(
        'onyx/guard_telemetry_test_native_validate_hikvision',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'validateHikvisionPayloadMapping') {
          final args = call.arguments! as Map;
          expect(args['provider_id'], 'hikvision_sdk');
          expect(args['payload_adapter'], 'hikvision_guardlink');
          final payload = args['payload'] as Map;
          expect(payload['vitals_hr'], 83);
          expect(payload['motion_index'], 0.63);
          return <String, Object?>{
            'accepted': true,
            'adapter_requested': 'hikvision_guardlink',
            'adapter_resolved': 'hikvision_guardlink',
            'normalized_payload': <String, Object?>{
              'heart_rate': 83,
              'movement_level': 0.63,
              'activity_state': 'patrolling',
              'captured_at_utc': '2026-03-05T14:06:00Z',
            },
          };
        }
        throw MissingPluginException('Unsupported method ${call.method}');
      });

      final adapter = NativeGuardTelemetryIngestionAdapter(
        config: const GuardTelemetryNativeSdkConfig(
          channel: channel,
          providerId: 'hikvision_sdk',
          stubMode: false,
        ),
      );

      final response = await adapter.validatePayloadMapping(
        payload: const <String, Object?>{
          'vitals_hr': 83,
          'motion_index': 0.63,
          'duty_state': 'patrolling',
          'event_utc': '2026-03-05T14:06:00Z',
        },
        payloadAdapter: 'hikvision_guardlink',
      );

      expect(response['accepted'], true);
      expect(response['adapter_requested'], 'hikvision_guardlink');
      expect(response['adapter_resolved'], 'hikvision_guardlink');

      messenger.setMockMethodCallHandler(channel, null);
    },
  );

  test(
    'native adapter emits debug heartbeat using provider-specific method for Hikvision',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel(
        'onyx/guard_telemetry_test_native_debug_hikvision',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'emitDebugHikvisionSdkHeartbeatBroadcast') {
          final args = call.arguments! as Map;
          expect(args['provider_id'], 'hikvision_sdk');
          expect(args['heart_rate'], 84);
          expect(args['movement_level'], 0.52);
          return <String, Object?>{'accepted': true};
        }
        throw MissingPluginException('Unsupported method ${call.method}');
      });

      final adapter = NativeGuardTelemetryIngestionAdapter(
        config: const GuardTelemetryNativeSdkConfig(
          channel: channel,
          providerId: 'hikvision_sdk',
          stubMode: false,
        ),
      );
      await adapter.emitDebugSdkHeartbeatBroadcast(
        sample: WearableTelemetrySample(
          heartRate: 84,
          movementLevel: 0.52,
          activityState: 'patrolling',
          batteryPercent: 87,
          capturedAtUtc: DateTime.utc(2026, 3, 5, 14, 7),
          source: 'test_debug',
          providerId: 'hikvision_sdk',
          sdkStatus: 'live',
        ),
      );

      messenger.setMockMethodCallHandler(channel, null);
    },
  );
}
