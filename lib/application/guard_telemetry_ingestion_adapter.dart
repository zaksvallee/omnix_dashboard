import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class WearableTelemetrySample {
  final int heartRate;
  final double movementLevel;
  final String activityState;
  final int? batteryPercent;
  final DateTime capturedAtUtc;
  final String source;
  final String? providerId;
  final String? sdkStatus;

  const WearableTelemetrySample({
    required this.heartRate,
    required this.movementLevel,
    required this.activityState,
    required this.batteryPercent,
    required this.capturedAtUtc,
    required this.source,
    this.providerId,
    this.sdkStatus,
  });
}

class DeviceHealthSample {
  final int batteryPercent;
  final double gpsAccuracyMeters;
  final int storageAvailableMb;
  final String networkState;
  final double deviceTemperatureC;
  final DateTime capturedAtUtc;
  final String source;
  final String? providerId;
  final String? sdkStatus;

  const DeviceHealthSample({
    required this.batteryPercent,
    required this.gpsAccuracyMeters,
    required this.storageAvailableMb,
    required this.networkState,
    required this.deviceTemperatureC,
    required this.capturedAtUtc,
    required this.source,
    this.providerId,
    this.sdkStatus,
  });
}

enum GuardTelemetryAdapterReadiness { ready, degraded, error }

class GuardTelemetryAdapterStatus {
  final GuardTelemetryAdapterReadiness readiness;
  final String message;
  final String adapterLabel;
  final bool isStub;
  final String? providerId;
  final String? facadeId;
  final bool? facadeLiveMode;
  final String? facadeToggleSource;
  final String? facadeRuntimeMode;
  final String? facadeHeartbeatSource;
  final String? facadeHeartbeatAction;
  final String? vendorConnectorId;
  final String? vendorConnectorSource;
  final String? vendorConnectorErrorMessage;
  final bool? vendorConnectorFallbackActive;
  final bool? facadeSourceActive;
  final int? facadeCallbackCount;
  final DateTime? facadeLastCallbackAtUtc;
  final String? facadeLastCallbackMessage;
  final int? facadeCallbackErrorCount;
  final DateTime? facadeLastCallbackErrorAtUtc;
  final String? facadeLastCallbackErrorMessage;

  const GuardTelemetryAdapterStatus({
    required this.readiness,
    required this.message,
    required this.adapterLabel,
    required this.isStub,
    this.providerId,
    this.facadeId,
    this.facadeLiveMode,
    this.facadeToggleSource,
    this.facadeRuntimeMode,
    this.facadeHeartbeatSource,
    this.facadeHeartbeatAction,
    this.vendorConnectorId,
    this.vendorConnectorSource,
    this.vendorConnectorErrorMessage,
    this.vendorConnectorFallbackActive,
    this.facadeSourceActive,
    this.facadeCallbackCount,
    this.facadeLastCallbackAtUtc,
    this.facadeLastCallbackMessage,
    this.facadeCallbackErrorCount,
    this.facadeLastCallbackErrorAtUtc,
    this.facadeLastCallbackErrorMessage,
  });
}

abstract class GuardTelemetryIngestionAdapter {
  String get adapterLabel;
  bool get isStub;
  Future<GuardTelemetryAdapterStatus> getStatus();
  Future<WearableTelemetrySample> captureWearableHeartbeat();
  Future<DeviceHealthSample> captureDeviceHealth();
}

class GuardTelemetryNativeSdkConfig {
  final MethodChannel channel;
  final String wearableMethod;
  final String deviceMethod;
  final String ingestWearableBridgeMethod;
  final String providerId;
  final bool stubMode;

  const GuardTelemetryNativeSdkConfig({
    this.channel = const MethodChannel('onyx/guard_telemetry'),
    this.wearableMethod = 'captureWearableHeartbeat',
    this.deviceMethod = 'captureDeviceHealth',
    this.ingestWearableBridgeMethod = 'ingestWearableHeartbeatBridge',
    this.providerId = 'android_native_sdk_stub',
    this.stubMode = true,
  });
}

class GuardTelemetryHttpConfig {
  final Uri wearableHeartbeatUri;
  final Uri deviceHealthUri;
  final String? bearerToken;

  const GuardTelemetryHttpConfig({
    required this.wearableHeartbeatUri,
    required this.deviceHealthUri,
    this.bearerToken,
  });

  static GuardTelemetryHttpConfig? fromEnvironment({
    required String wearableHeartbeatUrl,
    required String deviceHealthUrl,
    String? bearerToken,
  }) {
    final wearable = Uri.tryParse(wearableHeartbeatUrl.trim());
    final device = Uri.tryParse(deviceHealthUrl.trim());
    if (wearable == null || device == null) {
      return null;
    }
    final hasHttpWearable =
        wearable.isScheme('http') || wearable.isScheme('https');
    final hasHttpDevice = device.isScheme('http') || device.isScheme('https');
    if (!hasHttpWearable || !hasHttpDevice) {
      return null;
    }
    final token = bearerToken?.trim();
    return GuardTelemetryHttpConfig(
      wearableHeartbeatUri: wearable,
      deviceHealthUri: device,
      bearerToken: token == null || token.isEmpty ? null : token,
    );
  }
}

class DemoGuardTelemetryIngestionAdapter
    implements GuardTelemetryIngestionAdapter {
  final Random _random;
  final DateTime Function() _clock;

  DemoGuardTelemetryIngestionAdapter({
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random(),
       _clock = clock ?? DateTime.now;

  @override
  String get adapterLabel => 'demo_fallback';

  @override
  bool get isStub => true;

  @override
  Future<GuardTelemetryAdapterStatus> getStatus() async {
    return GuardTelemetryAdapterStatus(
      readiness: GuardTelemetryAdapterReadiness.degraded,
      message: 'Demo telemetry adapter active (stub mode).',
      adapterLabel: adapterLabel,
      isStub: isStub,
    );
  }

  @override
  Future<WearableTelemetrySample> captureWearableHeartbeat() async {
    final now = _clock().toUtc();
    return WearableTelemetrySample(
      heartRate: 66 + _random.nextInt(24),
      movementLevel: (_random.nextDouble() * 1.2).clamp(0.05, 1.2),
      activityState: _random.nextBool() ? 'patrolling' : 'stationary',
      batteryPercent: 30 + _random.nextInt(70),
      capturedAtUtc: now,
      source: 'demo_wearable_adapter',
      providerId: 'demo_fallback',
      sdkStatus: 'stub',
    );
  }

  @override
  Future<DeviceHealthSample> captureDeviceHealth() async {
    final now = _clock().toUtc();
    const networkStates = ['4G', '5G', 'wifi'];
    return DeviceHealthSample(
      batteryPercent: 28 + _random.nextInt(73),
      gpsAccuracyMeters: 2 + (_random.nextDouble() * 13),
      storageAvailableMb: 1200 + _random.nextInt(6800),
      networkState: networkStates[_random.nextInt(networkStates.length)],
      deviceTemperatureC: 30 + (_random.nextDouble() * 9),
      capturedAtUtc: now,
      source: 'demo_device_health_adapter',
      providerId: 'demo_fallback',
      sdkStatus: 'stub',
    );
  }
}

class HttpGuardTelemetryIngestionAdapter
    implements GuardTelemetryIngestionAdapter {
  final GuardTelemetryHttpConfig config;
  final http.Client client;

  const HttpGuardTelemetryIngestionAdapter({
    required this.config,
    required this.client,
  });

  @override
  String get adapterLabel => 'http_connector';

  @override
  bool get isStub => false;

  @override
  Future<GuardTelemetryAdapterStatus> getStatus() async {
    return GuardTelemetryAdapterStatus(
      readiness: GuardTelemetryAdapterReadiness.ready,
      message:
          'HTTP telemetry connector configured for ${config.wearableHeartbeatUri.host} and ${config.deviceHealthUri.host}.',
      adapterLabel: adapterLabel,
      isStub: isStub,
    );
  }

  @override
  Future<WearableTelemetrySample> captureWearableHeartbeat() async {
    final json = await _fetchJson(config.wearableHeartbeatUri);
    final capturedAtUtc = _readTimestamp(
      json,
      keys: const ['captured_at_utc', 'captured_at', 'timestamp'],
      fallback: DateTime.now().toUtc(),
    );
    final source = _readString(
      json,
      keys: const ['source', 'provider'],
      fallback: config.wearableHeartbeatUri.host,
    );
    return WearableTelemetrySample(
      heartRate: _readInt(
        json,
        keys: const ['heart_rate', 'heartRate'],
        fallback: 0,
      ),
      movementLevel: _readDouble(
        json,
        keys: const ['movement_level', 'movementLevel'],
        fallback: 0,
      ),
      activityState: _readString(
        json,
        keys: const ['activity_state', 'activityState'],
        fallback: 'unknown',
      ),
      batteryPercent: _readNullableInt(
        json,
        keys: const ['battery_percent', 'batteryPercent'],
      ),
      capturedAtUtc: capturedAtUtc,
      source: source,
      providerId: _readString(
        json,
        keys: const ['provider_id', 'providerId'],
        fallback: config.wearableHeartbeatUri.host,
      ),
      sdkStatus: _readString(
        json,
        keys: const ['sdk_status', 'sdkStatus'],
        fallback: 'live',
      ),
    );
  }

  @override
  Future<DeviceHealthSample> captureDeviceHealth() async {
    final json = await _fetchJson(config.deviceHealthUri);
    final capturedAtUtc = _readTimestamp(
      json,
      keys: const ['captured_at_utc', 'captured_at', 'timestamp'],
      fallback: DateTime.now().toUtc(),
    );
    final source = _readString(
      json,
      keys: const ['source', 'provider'],
      fallback: config.deviceHealthUri.host,
    );
    return DeviceHealthSample(
      batteryPercent: _readInt(
        json,
        keys: const ['battery_percent', 'batteryPercent'],
        fallback: 0,
      ),
      gpsAccuracyMeters: _readDouble(
        json,
        keys: const ['gps_accuracy_meters', 'gpsAccuracyMeters'],
        fallback: 0,
      ),
      storageAvailableMb: _readInt(
        json,
        keys: const ['storage_available_mb', 'storageAvailableMb'],
        fallback: 0,
      ),
      networkState: _readString(
        json,
        keys: const ['network_state', 'networkState'],
        fallback: 'unknown',
      ),
      deviceTemperatureC: _readDouble(
        json,
        keys: const ['device_temperature_c', 'deviceTemperatureC'],
        fallback: 0,
      ),
      capturedAtUtc: capturedAtUtc,
      source: source,
      providerId: _readString(
        json,
        keys: const ['provider_id', 'providerId'],
        fallback: config.deviceHealthUri.host,
      ),
      sdkStatus: _readString(
        json,
        keys: const ['sdk_status', 'sdkStatus'],
        fallback: 'live',
      ),
    );
  }

  Future<Map<String, Object?>> _fetchJson(Uri uri) async {
    final headers = <String, String>{'accept': 'application/json'};
    if (config.bearerToken != null) {
      headers['authorization'] = 'Bearer ${config.bearerToken}';
    }
    final response = await client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Telemetry endpoint failed (${response.statusCode}) for $uri',
      );
    }
    final decoded = jsonDecode(response.body);
    final map = _asMap(decoded) ?? _asMap((decoded as Map)['data']);
    if (map == null) {
      throw StateError('Telemetry payload is not an object for $uri');
    }
    return map;
  }

  Map<String, Object?>? _asMap(Object? value) {
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return null;
  }

  int _readInt(
    Map<String, Object?> json, {
    required List<String> keys,
    required int fallback,
  }) {
    final value = _readNullableInt(json, keys: keys);
    return value ?? fallback;
  }

  int? _readNullableInt(
    Map<String, Object?> json, {
    required List<String> keys,
  }) {
    final raw = _readRaw(json, keys: keys);
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  double _readDouble(
    Map<String, Object?> json, {
    required List<String> keys,
    required double fallback,
  }) {
    final raw = _readRaw(json, keys: keys);
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim()) ?? fallback;
    return fallback;
  }

  String _readString(
    Map<String, Object?> json, {
    required List<String> keys,
    required String fallback,
  }) {
    final raw = _readRaw(json, keys: keys);
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return fallback;
  }

  DateTime _readTimestamp(
    Map<String, Object?> json, {
    required List<String> keys,
    required DateTime fallback,
  }) {
    final raw = _readRaw(json, keys: keys);
    if (raw is String) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) return parsed.toUtc();
    }
    return fallback.toUtc();
  }

  Object? _readRaw(Map<String, Object?> json, {required List<String> keys}) {
    for (final key in keys) {
      if (json.containsKey(key)) return json[key];
    }
    return null;
  }
}

class NativeGuardTelemetryIngestionAdapter
    implements GuardTelemetryIngestionAdapter {
  final GuardTelemetryNativeSdkConfig config;

  const NativeGuardTelemetryIngestionAdapter({
    this.config = const GuardTelemetryNativeSdkConfig(),
  });

  @override
  String get adapterLabel => 'native_sdk:${config.providerId}';

  @override
  bool get isStub => config.stubMode;

  bool get _isHikvisionProvider {
    final provider = config.providerId.trim().toLowerCase();
    return provider.contains('hikvision');
  }

  String get _debugHeartbeatMethodName {
    return _isHikvisionProvider
        ? 'emitDebugHikvisionSdkHeartbeatBroadcast'
        : 'emitDebugFskSdkHeartbeatBroadcast';
  }

  String get _payloadValidationMethodName {
    return _isHikvisionProvider
        ? 'validateHikvisionPayloadMapping'
        : 'validateFskPayloadMapping';
  }

  @override
  Future<GuardTelemetryAdapterStatus> getStatus() async {
    try {
      final payload = await config.channel.invokeMapMethod<String, Object?>(
        'getTelemetryProviderStatus',
        <String, Object?>{'provider_id': config.providerId},
      );
      final readinessRaw = _stringValue(
        payload ?? const <String, Object?>{},
        const ['readiness'],
        config.stubMode ? 'degraded' : 'ready',
      );
      final readiness = switch (readinessRaw.toLowerCase()) {
        'ready' => GuardTelemetryAdapterReadiness.ready,
        'error' => GuardTelemetryAdapterReadiness.error,
        _ => GuardTelemetryAdapterReadiness.degraded,
      };
      final message = _stringValue(
        payload ?? const <String, Object?>{},
        const ['message'],
        config.stubMode
            ? 'Native provider is running in stub mode.'
            : 'Native provider status is available.',
      );
      final payloadAdapter = _stringValue(
        payload ?? const <String, Object?>{},
        const ['fsk_payload_adapter', 'hikvision_payload_adapter'],
        '',
      );
      final payloadAdapterSource = _stringValue(
        payload ?? const <String, Object?>{},
        const ['fsk_payload_adapter_source', 'hikvision_payload_adapter_source'],
        '',
      );
      final catalogHint = await _providerCatalogHint();
      final facadeId = _stringValue(
        payload ?? const <String, Object?>{},
        const ['facade_id', 'facadeId'],
        '',
      );
      final facadeToggleSource = _stringValue(
        payload ?? const <String, Object?>{},
        const ['facade_toggle_source', 'facadeToggleSource'],
        '',
      );
      final facadeLiveRaw = _rawValue(
        payload ?? const <String, Object?>{},
        const ['facade_live_mode', 'facadeLiveMode'],
      );
      final facadeLiveMode = switch (facadeLiveRaw) {
        bool value => value,
        String value => value.trim().toLowerCase() == 'true',
        _ => null,
      };
      final facadeRuntimeMode = _stringValue(
        payload ?? const <String, Object?>{},
        const ['facade_runtime_mode', 'runtime_mode'],
        '',
      );
      final facadeHeartbeatSource = _stringValue(
        payload ?? const <String, Object?>{},
        const ['facade_heartbeat_source', 'heartbeat_source'],
        '',
      );
      final facadeHeartbeatAction = _stringValue(
        payload ?? const <String, Object?>{},
        const ['facade_heartbeat_action', 'heartbeat_action'],
        '',
      );
      final vendorConnectorId = _stringValue(
        payload ?? const <String, Object?>{},
        const [
          'fsk_vendor_connector',
          'hikvision_vendor_connector',
          'vendor_connector',
        ],
        '',
      );
      final vendorConnectorSource = _stringValue(
        payload ?? const <String, Object?>{},
        const [
          'fsk_vendor_connector_source',
          'hikvision_vendor_connector_source',
          'vendor_connector_source',
        ],
        '',
      );
      final vendorConnectorErrorMessage = _stringValue(
        payload ?? const <String, Object?>{},
        const [
          'fsk_vendor_connector_error',
          'hikvision_vendor_connector_error',
          'vendor_connector_error',
        ],
        '',
      );
      final vendorConnectorFallbackActiveRaw = _rawValue(
        payload ?? const <String, Object?>{},
        const [
          'fsk_vendor_connector_fallback_active',
          'hikvision_vendor_connector_fallback_active',
          'vendor_connector_fallback_active',
        ],
      );
      final vendorConnectorFallbackActive = switch (
        vendorConnectorFallbackActiveRaw
      ) {
        bool value => value,
        String value => value.trim().toLowerCase() == 'true',
        _ => null,
      };
      final facadeSourceActiveRaw = _rawValue(
        payload ?? const <String, Object?>{},
        const ['facade_source_active', 'source_active'],
      );
      final facadeSourceActive = switch (facadeSourceActiveRaw) {
        bool value => value,
        String value => value.trim().toLowerCase() == 'true',
        _ => null,
      };
      final facadeCallbackCount = _nullableIntValue(
        payload ?? const <String, Object?>{},
        const ['facade_callback_count', 'callback_count'],
      );
      final facadeLastCallbackAtUtc = _nullableTimestampValue(
        payload ?? const <String, Object?>{},
        const ['facade_last_callback_at_utc', 'last_callback_at_utc'],
      );
      final facadeLastCallbackMessage = _stringValue(
        payload ?? const <String, Object?>{},
        const ['facade_last_callback_message', 'last_callback_message'],
        '',
      );
      final facadeCallbackErrorCount = _nullableIntValue(
        payload ?? const <String, Object?>{},
        const ['facade_callback_error_count', 'callback_error_count'],
      );
      final facadeLastCallbackErrorAtUtc = _nullableTimestampValue(
        payload ?? const <String, Object?>{},
        const [
          'facade_last_callback_error_at_utc',
          'last_callback_error_at_utc',
        ],
      );
      final facadeLastCallbackErrorMessage = _stringValue(
        payload ?? const <String, Object?>{},
        const [
          'facade_last_callback_error_message',
          'last_callback_error_message',
        ],
        '',
      );
      return GuardTelemetryAdapterStatus(
        readiness: readiness,
        message: readiness == GuardTelemetryAdapterReadiness.error
            ? _appendCatalogHint(message, catalogHint)
            : _appendVendorConnectorHint(
                _appendPayloadAdapterHint(
                  message,
                  payloadAdapter,
                  payloadAdapterSource,
                ),
                vendorConnectorErrorMessage,
              ),
        adapterLabel: adapterLabel,
        isStub: isStub,
        providerId: _stringValue(
          payload ?? const <String, Object?>{},
          const ['provider_id', 'providerId'],
          config.providerId,
        ),
        facadeId: facadeId.isEmpty ? null : facadeId,
        facadeLiveMode: facadeLiveMode,
        facadeToggleSource: facadeToggleSource.isEmpty
            ? null
            : facadeToggleSource,
        facadeRuntimeMode: facadeRuntimeMode.isEmpty ? null : facadeRuntimeMode,
        facadeHeartbeatSource: facadeHeartbeatSource.isEmpty
            ? null
            : facadeHeartbeatSource,
        facadeHeartbeatAction: facadeHeartbeatAction.isEmpty
            ? null
            : facadeHeartbeatAction,
        vendorConnectorId: vendorConnectorId.isEmpty ? null : vendorConnectorId,
        vendorConnectorSource: vendorConnectorSource.isEmpty
            ? null
            : vendorConnectorSource,
        vendorConnectorErrorMessage: vendorConnectorErrorMessage.isEmpty
            ? null
            : vendorConnectorErrorMessage,
        vendorConnectorFallbackActive: vendorConnectorFallbackActive,
        facadeSourceActive: facadeSourceActive,
        facadeCallbackCount: facadeCallbackCount,
        facadeLastCallbackAtUtc: facadeLastCallbackAtUtc,
        facadeLastCallbackMessage: facadeLastCallbackMessage.isEmpty
            ? null
            : facadeLastCallbackMessage,
        facadeCallbackErrorCount: facadeCallbackErrorCount,
        facadeLastCallbackErrorAtUtc: facadeLastCallbackErrorAtUtc,
        facadeLastCallbackErrorMessage: facadeLastCallbackErrorMessage.isEmpty
            ? null
            : facadeLastCallbackErrorMessage,
      );
    } on MissingPluginException {
      return GuardTelemetryAdapterStatus(
        readiness: GuardTelemetryAdapterReadiness.error,
        message: _appendCatalogHint(
          'Native telemetry channel is unavailable.',
          await _providerCatalogHint(),
        ),
        adapterLabel: adapterLabel,
        isStub: isStub,
      );
    } on PlatformException catch (error) {
      return GuardTelemetryAdapterStatus(
        readiness: GuardTelemetryAdapterReadiness.error,
        message: _appendCatalogHint(
          'Native telemetry status probe failed: ${error.message}',
          await _providerCatalogHint(),
        ),
        adapterLabel: adapterLabel,
        isStub: isStub,
      );
    } catch (error) {
      return GuardTelemetryAdapterStatus(
        readiness: GuardTelemetryAdapterReadiness.error,
        message: _appendCatalogHint(
          'Native telemetry status probe failed: $error',
          await _providerCatalogHint(),
        ),
        adapterLabel: adapterLabel,
        isStub: isStub,
      );
    }
  }

  @override
  Future<WearableTelemetrySample> captureWearableHeartbeat() async {
    final payload = await config.channel.invokeMapMethod<String, Object?>(
      config.wearableMethod,
      <String, Object?>{'provider_id': config.providerId},
    );
    if (payload == null) {
      throw StateError('Native wearable telemetry payload is empty.');
    }
    return WearableTelemetrySample(
      heartRate: _intValue(payload, const ['heart_rate', 'heartRate'], 0),
      movementLevel: _doubleValue(payload, const [
        'movement_level',
        'movementLevel',
      ], 0),
      activityState: _stringValue(payload, const [
        'activity_state',
        'activityState',
      ], 'unknown'),
      batteryPercent: _nullableIntValue(payload, const [
        'battery_percent',
        'batteryPercent',
      ]),
      capturedAtUtc: _timestampValue(payload, const [
        'captured_at_utc',
        'captured_at',
        'timestamp',
      ]),
      source: _stringValue(payload, const [
        'source',
        'provider',
      ], config.providerId),
      providerId: _stringValue(payload, const [
        'provider_id',
        'providerId',
      ], config.providerId),
      sdkStatus: _stringValue(payload, const [
        'sdk_status',
        'sdkStatus',
      ], config.stubMode ? 'stub' : 'live'),
    );
  }

  Future<void> ingestWearableHeartbeatBridge({
    required WearableTelemetrySample sample,
    double? gpsAccuracyMeters,
  }) async {
    await config.channel.invokeMethod<void>(
      config.ingestWearableBridgeMethod,
      <String, Object?>{
        'provider_id': config.providerId,
        'heart_rate': sample.heartRate,
        'movement_level': sample.movementLevel,
        'activity_state': sample.activityState,
        'battery_percent': sample.batteryPercent,
        'captured_at_utc': sample.capturedAtUtc.toUtc().toIso8601String(),
        'source': sample.source,
        'sdk_status': sample.sdkStatus ?? (config.stubMode ? 'stub' : 'live'),
        'gps_accuracy_meters': gpsAccuracyMeters,
      },
    );
  }

  Future<void> emitDebugSdkHeartbeatBroadcast({
    WearableTelemetrySample? sample,
    double? gpsAccuracyMeters,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final debugSample =
        sample ??
        WearableTelemetrySample(
          heartRate: 76,
          movementLevel: 0.71,
          activityState: 'patrolling',
          batteryPercent: 88,
          capturedAtUtc: nowUtc,
          source: 'onyx_debug_emit',
          providerId: config.providerId,
          sdkStatus: config.stubMode ? 'stub' : 'live',
        );
    final payload = await config.channel.invokeMapMethod<String, Object?>(
      _debugHeartbeatMethodName,
      <String, Object?>{
        'provider_id': config.providerId,
        'heart_rate': debugSample.heartRate,
        'movement_level': debugSample.movementLevel,
        'activity_state': debugSample.activityState,
        'battery_percent': debugSample.batteryPercent,
        'captured_at_utc': debugSample.capturedAtUtc.toIso8601String(),
        'gps_accuracy_meters': gpsAccuracyMeters ?? 3.8,
      },
    );
    final accepted = switch (_rawValue(
      payload ?? const <String, Object?>{},
      const ['accepted'],
    )) {
      bool value => value,
      String value => value.trim().toLowerCase() == 'true',
      _ => false,
    };
    if (!accepted) {
      final message = _stringValue(
        payload ?? const <String, Object?>{},
        const ['message'],
        'Debug heartbeat broadcast was not accepted.',
      );
      throw StateError(message);
    }
  }

  Future<Map<String, Object?>> validatePayloadMapping({
    required Map<String, Object?> payload,
    String? payloadAdapter,
  }) async {
    final response = await config.channel.invokeMapMethod<String, Object?>(
      _payloadValidationMethodName,
      <String, Object?>{
        'provider_id': config.providerId,
        'payload': payload,
        'payload_adapter': payloadAdapter,
      },
    );
    return response ?? const <String, Object?>{};
  }

  Future<void> emitDebugFskSdkHeartbeatBroadcast({
    WearableTelemetrySample? sample,
    double? gpsAccuracyMeters,
  }) {
    return emitDebugSdkHeartbeatBroadcast(
      sample: sample,
      gpsAccuracyMeters: gpsAccuracyMeters,
    );
  }

  Future<Map<String, Object?>> validateFskPayloadMapping({
    required Map<String, Object?> payload,
    String? payloadAdapter,
  }) {
    return validatePayloadMapping(payload: payload, payloadAdapter: payloadAdapter);
  }

  @override
  Future<DeviceHealthSample> captureDeviceHealth() async {
    final payload = await config.channel.invokeMapMethod<String, Object?>(
      config.deviceMethod,
      <String, Object?>{'provider_id': config.providerId},
    );
    if (payload == null) {
      throw StateError('Native device health payload is empty.');
    }
    return DeviceHealthSample(
      batteryPercent: _intValue(payload, const [
        'battery_percent',
        'batteryPercent',
      ], 0),
      gpsAccuracyMeters: _doubleValue(payload, const [
        'gps_accuracy_meters',
        'gpsAccuracyMeters',
      ], 0),
      storageAvailableMb: _intValue(payload, const [
        'storage_available_mb',
        'storageAvailableMb',
      ], 0),
      networkState: _stringValue(payload, const [
        'network_state',
        'networkState',
      ], 'unknown'),
      deviceTemperatureC: _doubleValue(payload, const [
        'device_temperature_c',
        'deviceTemperatureC',
      ], 0),
      capturedAtUtc: _timestampValue(payload, const [
        'captured_at_utc',
        'captured_at',
        'timestamp',
      ]),
      source: _stringValue(payload, const [
        'source',
        'provider',
      ], config.providerId),
      providerId: _stringValue(payload, const [
        'provider_id',
        'providerId',
      ], config.providerId),
      sdkStatus: _stringValue(payload, const [
        'sdk_status',
        'sdkStatus',
      ], config.stubMode ? 'stub' : 'live'),
    );
  }

  int _intValue(Map<String, Object?> json, List<String> keys, int fallback) {
    final parsed = _nullableIntValue(json, keys);
    return parsed ?? fallback;
  }

  int? _nullableIntValue(Map<String, Object?> json, List<String> keys) {
    final raw = _rawValue(json, keys);
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  double _doubleValue(
    Map<String, Object?> json,
    List<String> keys,
    double fallback,
  ) {
    final raw = _rawValue(json, keys);
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim()) ?? fallback;
    return fallback;
  }

  String _stringValue(
    Map<String, Object?> json,
    List<String> keys,
    String fallback,
  ) {
    final raw = _rawValue(json, keys);
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return fallback;
  }

  DateTime _timestampValue(Map<String, Object?> json, List<String> keys) {
    final raw = _rawValue(json, keys);
    if (raw is String) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) return parsed.toUtc();
    }
    return DateTime.now().toUtc();
  }

  Object? _rawValue(Map<String, Object?> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) return json[key];
    }
    return null;
  }

  DateTime? _nullableTimestampValue(
    Map<String, Object?> json,
    List<String> keys,
  ) {
    final raw = _rawValue(json, keys);
    if (raw is String) {
      final parsed = DateTime.tryParse(raw.trim());
      return parsed?.toUtc();
    }
    return null;
  }

  Future<String?> _providerCatalogHint() async {
    try {
      final payload = await config.channel.invokeMapMethod<String, Object?>(
        'listTelemetryProviders',
        <String, Object?>{'provider_id': config.providerId},
      );
      if (payload == null) return null;
      final raw = _rawValue(payload, const ['available_provider_ids']);
      if (raw is List) {
        final values = raw
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
        if (values.isNotEmpty) {
          return 'Available providers: ${values.join(', ')}.';
        }
      }
    } catch (_) {
      // Keep status probe resilient when provider catalog is unavailable.
    }
    return null;
  }

  String _appendCatalogHint(String message, String? catalogHint) {
    final trimmedMessage = message.trim();
    final trimmedHint = catalogHint?.trim() ?? '';
    if (trimmedHint.isEmpty) return trimmedMessage;
    if (trimmedMessage.contains(trimmedHint)) return trimmedMessage;
    return '$trimmedMessage $trimmedHint';
  }

  String _appendPayloadAdapterHint(
    String message,
    String payloadAdapter,
    String payloadAdapterSource,
  ) {
    final normalizedAdapter = payloadAdapter.trim();
    if (normalizedAdapter.isEmpty) return message.trim();
    final normalizedSource = payloadAdapterSource.trim();
    final hint = normalizedSource.isEmpty
        ? 'Payload adapter: $normalizedAdapter.'
        : 'Payload adapter: $normalizedAdapter ($normalizedSource).';
    return _appendCatalogHint(message, hint);
  }

  String _appendVendorConnectorHint(String message, String connectorError) {
    final normalizedError = connectorError.trim();
    if (normalizedError.isEmpty) return message.trim();
    final hint = 'Vendor connector warning: $normalizedError';
    return _appendCatalogHint(message, hint);
  }
}

GuardTelemetryIngestionAdapter createGuardTelemetryIngestionAdapter({
  required String wearableHeartbeatUrl,
  required String deviceHealthUrl,
  String? bearerToken,
  bool preferNativeSdk = false,
  GuardTelemetryNativeSdkConfig nativeSdkConfig =
      const GuardTelemetryNativeSdkConfig(),
  http.Client? client,
  Random? random,
  DateTime Function()? clock,
}) {
  if (preferNativeSdk && !kIsWeb) {
    return NativeGuardTelemetryIngestionAdapter(config: nativeSdkConfig);
  }
  final config = GuardTelemetryHttpConfig.fromEnvironment(
    wearableHeartbeatUrl: wearableHeartbeatUrl,
    deviceHealthUrl: deviceHealthUrl,
    bearerToken: bearerToken,
  );
  if (config == null) {
    return DemoGuardTelemetryIngestionAdapter(random: random, clock: clock);
  }
  return HttpGuardTelemetryIngestionAdapter(
    config: config,
    client: client ?? http.Client(),
  );
}
