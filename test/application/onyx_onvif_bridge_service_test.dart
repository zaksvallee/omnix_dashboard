import 'dart:async';

import 'package:easy_onvif/onvif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggy/loggy.dart';
import 'package:omnix_dashboard/application/onvif/onyx_onvif_bridge_service.dart';
import 'package:omnix_dashboard/application/onvif/onyx_onvif_device.dart';
import 'package:omnix_dashboard/application/onvif/onyx_onvif_exceptions.dart';

void main() {
  group('OnyxEasyOnvifBridgeService', () {
    late FakeOnyxOnvifRuntime runtime;
    late OnyxEasyOnvifBridgeService service;
    late OnyxOnvifDevice device;

    setUp(() {
      runtime = FakeOnyxOnvifRuntime();
      service = OnyxEasyOnvifBridgeService(runtime: runtime);
      device = const OnyxOnvifDevice(
        id: '0dca4f32-fd2f-4c1a-8f80-aed994dbe7f5',
        host: '192.168.1.20',
        username: 'operator',
        password: 'secret',
      );
    });

    test('discoverDevices returns empty list on timeout', () async {
      runtime.discoverError = TimeoutException('discovery timed out');

      final result = await service.discoverDevices();

      expect(result, isEmpty);
    });

    test('connect throws OnyxOnvifAuthException on bad credentials', () async {
      runtime.connectError = Exception('401 Unauthorized');

      expect(
        () => service.connect(device),
        throwsA(isA<OnyxOnvifAuthException>()),
      );
    });

    test('getProfiles returns list of OnyxOnvifProfile', () async {
      const expectedProfiles = <OnyxOnvifProfile>[
        OnyxOnvifProfile(
          token: 'profile-main',
          name: 'Main Stream',
          streamUri: 'rtsp://camera/main',
          snapshotUri: 'http://camera/main.jpg',
        ),
      ];

      runtime.profiles = expectedProfiles;

      await service.connect(device);
      final profiles = await service.getProfiles(device);

      expect(profiles, expectedProfiles);
    });

    test('ptzMove does not throw on valid input', () async {
      await service.connect(device);

      await expectLater(
        service.ptzMove(
          device,
          'profile-main',
          pan: 0.2,
          tilt: -0.1,
          zoom: 0.3,
        ),
        completes,
      );
      expect(runtime.ptzMoveCallCount, 1);
    });

    test('disconnect cleans up connection map entry', () async {
      await service.connect(device);

      expect(service.hasConnection(device.id), isTrue);
      expect(service.activeConnectionCount, 1);

      await service.disconnect(device);

      expect(service.hasConnection(device.id), isFalse);
      expect(service.activeConnectionCount, 0);
    });
  });
}

class FakeOnyxOnvifRuntime implements OnyxOnvifRuntime {
  final Onvif connection = _FakeOnvifConnection();

  Object? discoverError;
  Object? connectError;
  Object? deviceInfoError;
  Object? profilesError;
  Object? ptzMoveError;
  Object? disconnectError;
  List<OnyxOnvifDevice> discoveredDevices = const <OnyxOnvifDevice>[];
  List<OnyxOnvifProfile> profiles = const <OnyxOnvifProfile>[];
  List<dynamic> presets = const <dynamic>[];
  int ptzMoveCallCount = 0;

  @override
  Future<Onvif> connect(OnyxOnvifDevice device) async {
    if (connectError != null) {
      throw connectError!;
    }
    return connection;
  }

  @override
  Future<List<OnyxOnvifDevice>> discover({required Duration timeout}) async {
    if (discoverError != null) {
      throw discoverError!;
    }
    return discoveredDevices;
  }

  @override
  Future<OnyxOnvifDevice> getDeviceInfo(
    Onvif connection,
    OnyxOnvifDevice device,
  ) async {
    if (deviceInfoError != null) {
      throw deviceInfoError!;
    }

    return device.copyWith(
      name: 'Warehouse Camera',
      manufacturer: 'Acme Vision',
      model: 'VX-210',
      firmwareVersion: '1.2.3',
      isReachable: true,
      lastSeen: DateTime.utc(2026, 4, 8, 8),
    );
  }

  @override
  Future<List<OnyxOnvifProfile>> getProfiles(Onvif connection) async {
    if (profilesError != null) {
      throw profilesError!;
    }
    return profiles;
  }

  @override
  Future<String?> getSnapshotUri(Onvif connection, String profileToken) async {
    final match = profiles.where((profile) => profile.token == profileToken);
    return match.isEmpty ? null : match.first.snapshotUri;
  }

  @override
  Future<String?> getStreamUri(Onvif connection, String profileToken) async {
    final match = profiles.where((profile) => profile.token == profileToken);
    return match.isEmpty ? null : match.first.streamUri;
  }

  @override
  Future<List<dynamic>> getPresets(
    Onvif connection,
    String profileToken,
  ) async {
    return presets;
  }

  @override
  Future<void> gotoPreset(
    Onvif connection,
    String profileToken,
    String presetToken,
  ) async {}

  @override
  Future<void> ptzMove(
    Onvif connection,
    String profileToken, {
    double pan = 0,
    double tilt = 0,
    double zoom = 0,
  }) async {
    if (ptzMoveError != null) {
      throw ptzMoveError!;
    }
    ptzMoveCallCount += 1;
  }

  @override
  Future<void> ptzStop(Onvif connection, String profileToken) async {}
}

class _FakeOnvifConnection extends Onvif {
  _FakeOnvifConnection()
    : super(
        authInfo: AuthInfo(
          host: '127.0.0.1',
          username: 'test',
          password: 'test',
        ),
        logOptions: const LogOptions(
          LogLevel.error,
          stackTraceLevel: LogLevel.off,
        ),
        printer: const PrettyPrinter(showColors: false),
      );
}
