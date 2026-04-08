import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:easy_onvif/device_management.dart';
import 'package:easy_onvif/onvif.dart';
import 'package:easy_onvif/probe.dart';
import 'package:easy_onvif/shared.dart';
import 'package:easy_onvif/util.dart';

import 'onyx_onvif_device.dart';
import 'onyx_onvif_exceptions.dart';

/// ONVIF on Flutter Web: WS-Discovery uses UDP multicast which is blocked by
/// browsers. Use [discoverDevices] on native platforms. On web, add devices
/// manually via host/port or implement a backend relay.
abstract class OnyxOnvifBridgeService {
  Future<List<OnyxOnvifDevice>> discoverDevices({
    Duration timeout = const Duration(seconds: 5),
  });

  Future<OnyxOnvifDevice> connect(OnyxOnvifDevice device);

  Future<OnyxOnvifDevice> getDeviceInfo(OnyxOnvifDevice device);

  Future<List<OnyxOnvifProfile>> getProfiles(OnyxOnvifDevice device);

  Future<String?> getStreamUri(OnyxOnvifDevice device, String profileToken);

  Future<String?> getSnapshotUri(OnyxOnvifDevice device, String profileToken);

  Future<void> ptzMove(
    OnyxOnvifDevice device,
    String profileToken, {
    double pan = 0,
    double tilt = 0,
    double zoom = 0,
  });

  Future<void> ptzStop(OnyxOnvifDevice device, String profileToken);

  Future<List<dynamic>> getPresets(OnyxOnvifDevice device, String profileToken);

  Future<void> gotoPreset(
    OnyxOnvifDevice device,
    String profileToken,
    String presetToken,
  );

  Future<void> disconnect(OnyxOnvifDevice device);
}

abstract class OnyxOnvifRuntime {
  Future<List<OnyxOnvifDevice>> discover({required Duration timeout});

  Future<Onvif> connect(OnyxOnvifDevice device);

  Future<OnyxOnvifDevice> getDeviceInfo(
    Onvif connection,
    OnyxOnvifDevice device,
  );

  Future<List<OnyxOnvifProfile>> getProfiles(Onvif connection);

  Future<String?> getStreamUri(Onvif connection, String profileToken);

  Future<String?> getSnapshotUri(Onvif connection, String profileToken);

  Future<void> ptzMove(
    Onvif connection,
    String profileToken, {
    double pan = 0,
    double tilt = 0,
    double zoom = 0,
  });

  Future<void> ptzStop(Onvif connection, String profileToken);

  Future<List<dynamic>> getPresets(Onvif connection, String profileToken);

  Future<void> gotoPreset(
    Onvif connection,
    String profileToken,
    String presetToken,
  );
}

class OnyxEasyOnvifBridgeService implements OnyxOnvifBridgeService {
  final OnyxOnvifRuntime _runtime;
  final Map<String, Onvif> _connections = <String, Onvif>{};

  OnyxEasyOnvifBridgeService({OnyxOnvifRuntime? runtime})
    : _runtime = runtime ?? const _EasyOnvifRuntime();

  int get activeConnectionCount => _connections.length;

  bool hasConnection(String deviceId) => _connections.containsKey(deviceId);

  @override
  Future<List<OnyxOnvifDevice>> discoverDevices({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // On web, WS-Discovery cannot use browser UDP multicast, so direct device
    // configuration or a backend relay is required instead of in-browser probe.
    try {
      return await _runtime.discover(timeout: timeout);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to discover ONVIF devices.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );

      final mapped = _mapException(
        error,
        fallbackMessage: 'Unable to discover ONVIF devices.',
      );

      if (mapped is OnyxOnvifTimeoutException) {
        return const <OnyxOnvifDevice>[];
      }

      throw mapped;
    }
  }

  @override
  Future<OnyxOnvifDevice> connect(OnyxOnvifDevice device) async {
    try {
      final connection = await _runtime.connect(device);
      _connections[device.id] = connection;

      try {
        final deviceInfo = await getDeviceInfo(device);

        try {
          final profiles = await getProfiles(deviceInfo);
          return deviceInfo.copyWith(profiles: profiles);
        } catch (error, stackTrace) {
          developer.log(
            'Connected to ONVIF device but profiles could not be loaded.',
            name: 'OnyxOnvifBridge',
            error: error,
            stackTrace: stackTrace,
          );

          if (error is OnyxOnvifCapabilityException) {
            return deviceInfo.copyWith(profiles: const <OnyxOnvifProfile>[]);
          }

          rethrow;
        }
      } catch (error, stackTrace) {
        developer.log(
          'Failed to hydrate ONVIF device after connecting.',
          name: 'OnyxOnvifBridge',
          error: error,
          stackTrace: stackTrace,
        );
        _connections.remove(device.id);
        rethrow;
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to connect to ONVIF device ${device.host}:${device.port}.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapException(
        error,
        fallbackMessage: 'Unable to connect to ONVIF device.',
      );
    }
  }

  @override
  Future<OnyxOnvifDevice> getDeviceInfo(OnyxOnvifDevice device) async {
    return _guard('load ONVIF device info', () async {
      final connection = await _ensureConnection(device);
      return _runtime.getDeviceInfo(connection, device);
    });
  }

  @override
  Future<List<OnyxOnvifProfile>> getProfiles(OnyxOnvifDevice device) async {
    return _guard('load ONVIF profiles', () async {
      final connection = await _ensureConnection(device);
      return _runtime.getProfiles(connection);
    });
  }

  @override
  Future<String?> getStreamUri(
    OnyxOnvifDevice device,
    String profileToken,
  ) async {
    return _guard('load ONVIF stream URI', () async {
      final connection = await _ensureConnection(device);
      return _runtime.getStreamUri(connection, profileToken);
    });
  }

  @override
  Future<String?> getSnapshotUri(
    OnyxOnvifDevice device,
    String profileToken,
  ) async {
    return _guard('load ONVIF snapshot URI', () async {
      final connection = await _ensureConnection(device);
      return _runtime.getSnapshotUri(connection, profileToken);
    });
  }

  @override
  Future<void> ptzMove(
    OnyxOnvifDevice device,
    String profileToken, {
    double pan = 0,
    double tilt = 0,
    double zoom = 0,
  }) async {
    return _guard('move ONVIF PTZ camera', () async {
      final connection = await _ensureConnection(device);
      await _runtime.ptzMove(
        connection,
        profileToken,
        pan: pan,
        tilt: tilt,
        zoom: zoom,
      );
    });
  }

  @override
  Future<void> ptzStop(OnyxOnvifDevice device, String profileToken) async {
    return _guard('stop ONVIF PTZ camera', () async {
      final connection = await _ensureConnection(device);
      await _runtime.ptzStop(connection, profileToken);
    });
  }

  @override
  Future<List<dynamic>> getPresets(
    OnyxOnvifDevice device,
    String profileToken,
  ) async {
    return _guard('load ONVIF presets', () async {
      final connection = await _ensureConnection(device);
      return _runtime.getPresets(connection, profileToken);
    });
  }

  @override
  Future<void> gotoPreset(
    OnyxOnvifDevice device,
    String profileToken,
    String presetToken,
  ) async {
    return _guard('move ONVIF camera to preset', () async {
      final connection = await _ensureConnection(device);
      await _runtime.gotoPreset(connection, profileToken, presetToken);
    });
  }

  @override
  Future<void> disconnect(OnyxOnvifDevice device) async {
    _connections.remove(device.id);
  }

  Future<Onvif> _ensureConnection(OnyxOnvifDevice device) async {
    final existingConnection = _connections[device.id];
    if (existingConnection != null) {
      return existingConnection;
    }

    final connection = await _runtime.connect(device);
    _connections[device.id] = connection;
    return connection;
  }

  Future<T> _guard<T>(String action, Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to $action.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapException(error, fallbackMessage: 'Unable to $action.');
    }
  }

  OnyxOnvifException _mapException(
    Object error, {
    required String fallbackMessage,
  }) {
    if (error is OnyxOnvifException) {
      return error;
    }

    if (error is TimeoutException) {
      return OnyxOnvifTimeoutException(fallbackMessage, cause: error);
    }

    if (error is NotSupportedException || error is UnsupportedError) {
      return OnyxOnvifCapabilityException(fallbackMessage, cause: error);
    }

    final message = error.toString().toLowerCase();

    if (message.contains('401') ||
        message.contains('403') ||
        message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('auth')) {
      return OnyxOnvifAuthException(fallbackMessage, cause: error);
    }

    if (message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('deadline exceeded')) {
      return OnyxOnvifTimeoutException(fallbackMessage, cause: error);
    }

    if (message.contains('not supported') ||
        message.contains('service not available') ||
        message.contains('ptz services not available') ||
        message.contains('media services not available')) {
      return OnyxOnvifCapabilityException(fallbackMessage, cause: error);
    }

    return OnyxOnvifConnectionException(fallbackMessage, cause: error);
  }
}

class _EasyOnvifRuntime implements OnyxOnvifRuntime {
  const _EasyOnvifRuntime();

  @override
  Future<List<OnyxOnvifDevice>> discover({required Duration timeout}) async {
    try {
      final probe = MulticastProbe(timeout: _timeoutSeconds(timeout));
      await probe.probe();
      return probe.onvifDevices
          .map(_deviceFromProbeMatch)
          .toList(growable: false);
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif discovery failed.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<Onvif> connect(OnyxOnvifDevice device) async {
    try {
      return Onvif.connect(
        host: _formatHost(device),
        username: device.username,
        password: device.password,
      );
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif connection failed for ${device.host}:${device.port}.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<OnyxOnvifDevice> getDeviceInfo(
    Onvif connection,
    OnyxOnvifDevice device,
  ) async {
    try {
      final response = await connection.deviceManagement.getDeviceInformation();
      final resolvedName = _resolvedDeviceName(device.name, response);

      return device.copyWith(
        name: resolvedName,
        manufacturer: response.manufacturer,
        model: response.model,
        firmwareVersion: response.firmwareVersion?.toString(),
        isReachable: true,
        lastSeen: DateTime.now(),
      );
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif device info lookup failed.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<OnyxOnvifProfile>> getProfiles(Onvif connection) async {
    try {
      final profiles = await connection.media.getProfiles();
      final mappedProfiles = <OnyxOnvifProfile>[];

      for (final profile in profiles) {
        mappedProfiles.add(
          OnyxOnvifProfile(
            token: profile.token,
            name: profile.name,
            streamUri: await _tryGetStreamUri(connection, profile.token),
            snapshotUri: await _tryGetSnapshotUri(connection, profile.token),
          ),
        );
      }

      return List<OnyxOnvifProfile>.unmodifiable(mappedProfiles);
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif profile lookup failed.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<String?> getStreamUri(Onvif connection, String profileToken) async {
    try {
      return await connection.media.getStreamUri(profileToken);
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif stream URI lookup failed for profile $profileToken.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<String?> getSnapshotUri(Onvif connection, String profileToken) async {
    try {
      return await connection.media.getSnapshotUri(profileToken);
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif snapshot URI lookup failed for profile $profileToken.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> ptzMove(
    Onvif connection,
    String profileToken, {
    double pan = 0,
    double tilt = 0,
    double zoom = 0,
  }) async {
    try {
      await connection.ptz.continuousMove(
        profileToken,
        velocity: PtzSpeed(
          panTilt: Vector2D(x: pan, y: tilt),
          zoom: Vector1D(x: zoom),
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif PTZ move failed for profile $profileToken.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> ptzStop(Onvif connection, String profileToken) async {
    try {
      await connection.ptz.stop(profileToken);
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif PTZ stop failed for profile $profileToken.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getPresets(
    Onvif connection,
    String profileToken,
  ) async {
    try {
      final presets = await connection.ptz.getPresets(profileToken);
      return List<dynamic>.unmodifiable(presets);
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif preset lookup failed for profile $profileToken.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> gotoPreset(
    Onvif connection,
    String profileToken,
    String presetToken,
  ) async {
    try {
      await connection.ptz.gotoPreset(profileToken, presetToken: presetToken);
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif goto preset failed for profile $profileToken.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<String?> _tryGetStreamUri(
    Onvif connection,
    String profileToken,
  ) async {
    try {
      return await connection.media.getStreamUri(profileToken);
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif profile stream URI lookup failed for $profileToken.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<String?> _tryGetSnapshotUri(
    Onvif connection,
    String profileToken,
  ) async {
    try {
      return await connection.media.getSnapshotUri(profileToken);
    } catch (error, stackTrace) {
      developer.log(
        'easy_onvif profile snapshot URI lookup failed for $profileToken.',
        name: 'OnyxOnvifBridge',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  OnyxOnvifDevice _deviceFromProbeMatch(ProbeMatch match) {
    final serviceUri = Uri.tryParse(match.xAddr);
    final host = serviceUri?.host.isNotEmpty == true
        ? serviceUri!.host
        : match.xAddr;
    final name = match.name.trim().isEmpty ? null : match.name.trim();
    final manufacturer = match.hardware.trim().isEmpty
        ? null
        : match.hardware.trim();
    final model = match.type.trim().isEmpty ? null : match.type.trim();

    return OnyxOnvifDevice(
      id: _extractUuid(match.endpointReference.address),
      host: host,
      port: serviceUri?.hasPort == true ? serviceUri!.port : 80,
      username: '',
      password: '',
      name: name,
      manufacturer: manufacturer,
      model: model,
      profiles: const <OnyxOnvifProfile>[],
      isReachable: true,
      lastSeen: DateTime.now(),
    );
  }

  String _extractUuid(String candidate) {
    final uuidMatch = RegExp(
      r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
    ).firstMatch(candidate);

    if (uuidMatch != null) {
      return uuidMatch.group(1)!.toLowerCase();
    }

    return _generateUuid();
  }

  String _formatHost(OnyxOnvifDevice device) {
    if (device.host.startsWith('http://') ||
        device.host.startsWith('https://')) {
      if (device.port == 80) {
        return device.host;
      }

      final parsed = Uri.parse(device.host);
      return parsed.replace(port: device.port).toString();
    }

    if (device.port == 80) {
      return device.host;
    }

    return 'http://${device.host}:${device.port}';
  }

  String? _resolvedDeviceName(
    String? currentName,
    GetDeviceInformationResponse response,
  ) {
    if (currentName != null && currentName.trim().isNotEmpty) {
      return currentName;
    }

    final parts = <String>[
      if ((response.manufacturer ?? '').trim().isNotEmpty)
        response.manufacturer!.trim(),
      if ((response.model ?? '').trim().isNotEmpty) response.model!.trim(),
    ];

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' ');
  }

  int _timeoutSeconds(Duration timeout) {
    if (timeout.inMilliseconds <= 0) {
      return 1;
    }

    return (timeout.inMilliseconds / Duration.millisecondsPerSecond).ceil();
  }

  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();

    return <String>[
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20, 32),
    ].join('-');
  }
}
