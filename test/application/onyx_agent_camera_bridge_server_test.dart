import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_receiver.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_stub.dart'
    as bridge_stub;
import 'package:omnix_dashboard/application/onyx_agent_camera_change_service.dart';

void main() {
  group('LocalHttpOnyxAgentCameraBridgeServer', () {
    test(
      'accepts execute packets and routes them through the receiver',
      () async {
        final server = createOnyxAgentCameraBridgeServer(
          receiver: OnyxAgentCameraBridgeReceiver(
            workers: const <OnyxAgentCameraVendorWorker>[
              _FakeBridgeWorker(),
            ],
          ),
          host: '127.0.0.1',
          port: 0,
        );
        addTearDown(server.close);
        await server.start();

        final client = http.Client();
        addTearDown(client.close);
        final response = await client.post(
          server.endpoint!.replace(path: '/execute'),
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(_buildRequest(vendorKey: 'hikvision').toJson()),
        );

        expect(response.statusCode, 200);
        final decoded = jsonDecode(response.body) as Map<String, Object?>;
        expect(decoded['success'], true);
        expect(decoded['worker_label'], 'Fake Camera Worker');
        final packet = decoded['execution_packet'] as Map<String, Object?>;
        expect(packet['vendor_key'], 'hikvision');
        expect(packet['profile_label'], 'Alarm Verification');
      },
    );

    test('rejects unauthorized requests when a token is configured', () async {
      final server = createOnyxAgentCameraBridgeServer(
        receiver: const OnyxAgentCameraBridgeReceiver(),
        host: '127.0.0.1',
        port: 0,
        authToken: 'bridge-secret',
      );
      addTearDown(server.close);
      await server.start();

      final client = http.Client();
      addTearDown(client.close);
      final response = await client.post(
        server.endpoint!.replace(path: '/execute'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(_buildRequest().toJson()),
      );

      expect(response.statusCode, 401);
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      expect(decoded['success'], false);
      expect(
        decoded['detail'],
        contains('Provide the configured bearer token'),
      );
    });

    test('returns 400 when the body is not valid json', () async {
      final server = createOnyxAgentCameraBridgeServer(
        receiver: const OnyxAgentCameraBridgeReceiver(),
        host: '127.0.0.1',
        port: 0,
      );
      addTearDown(server.close);
      await server.start();

      final client = http.Client();
      addTearDown(client.close);
      final response = await client.post(
        server.endpoint!.replace(path: '/execute'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: '{invalid',
      );

      expect(response.statusCode, 400);
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      expect(decoded['success'], false);
      expect(decoded['provider_label'], 'local:camera-bridge-server');
      expect(decoded['detail'], contains('could not be parsed as JSON'));
      expect(
        decoded['recommended_next_step'],
        contains('Submit a valid JSON camera execution packet'),
      );
      expect((decoded['recorded_at_utc'] ?? '').toString(), isNotEmpty);
    });

    test(
      'returns structured receiver error when required fields are missing',
      () async {
        final server = createOnyxAgentCameraBridgeServer(
          receiver: const OnyxAgentCameraBridgeReceiver(),
          host: '127.0.0.1',
          port: 0,
        );
        addTearDown(server.close);
        await server.start();

        final client = http.Client();
        addTearDown(client.close);
        final response = await client.post(
          server.endpoint!.replace(path: '/execute'),
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, Object?>{
            'packet_id': 'CAM-PKT-BRIDGE-1',
            'target': '10.55.8.14',
          }),
        );

        expect(response.statusCode, 422);
        final decoded = jsonDecode(response.body) as Map<String, Object?>;
        expect(decoded['success'], false);
        expect(decoded['provider_label'], 'local:camera-bridge-receiver');
        expect(decoded['detail'], contains('execution packet was invalid'));
        expect(
          decoded['recommended_next_step'],
          contains('Re-stage the camera change packet'),
        );
        expect((decoded['recorded_at_utc'] ?? '').toString(), isNotEmpty);
      },
    );

    test(
      'returns structured error when the body decodes but is not a json object',
      () async {
        final server = createOnyxAgentCameraBridgeServer(
          receiver: const OnyxAgentCameraBridgeReceiver(),
          host: '127.0.0.1',
          port: 0,
        );
        addTearDown(server.close);
        await server.start();

        final client = http.Client();
        addTearDown(client.close);
        final response = await client.post(
          server.endpoint!.replace(path: '/execute'),
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<Object?>['not', 'an', 'object']),
        );

        expect(response.statusCode, 400);
        final decoded = jsonDecode(response.body) as Map<String, Object?>;
        expect(decoded['success'], false);
        expect(decoded['provider_label'], 'local:camera-bridge-server');
        expect(decoded['detail'], contains('must be a JSON object'));
        expect(decoded['recommended_next_step'], contains('JSON object'));
        expect((decoded['recorded_at_utc'] ?? '').toString(), isNotEmpty);
      },
    );

    test('serves health checks with the active endpoint', () async {
      final server = createOnyxAgentCameraBridgeServer(
        receiver: const OnyxAgentCameraBridgeReceiver(),
        host: '127.0.0.1',
        port: 0,
      );
      addTearDown(server.close);
      await server.start();

      final client = http.Client();
      addTearDown(client.close);
      final response = await client.get(
        server.endpoint!.replace(path: '/health'),
      );

      expect(response.statusCode, 200);
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      expect(decoded['status'], 'ok');
      expect(decoded['running'], true);
      expect(decoded['execute_path'], '/execute');
      expect(decoded['endpoint'], server.endpoint.toString());
    });

    test(
      'stops serving execute requests after close and accepts them again after restart',
      () async {
        final server = createOnyxAgentCameraBridgeServer(
          receiver: OnyxAgentCameraBridgeReceiver(
            workers: const <OnyxAgentCameraVendorWorker>[
              _FakeBridgeWorker(),
            ],
          ),
          host: '127.0.0.1',
          port: 0,
        );
        addTearDown(server.close);

        final client = http.Client();
        addTearDown(client.close);

        await server.start();
        final firstEndpoint = server.endpoint!;
        final firstResponse = await client.post(
          firstEndpoint.replace(path: '/execute'),
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(_buildRequest(vendorKey: 'hikvision').toJson()),
        );

        expect(firstResponse.statusCode, 200);
        expect(server.isRunning, isTrue);

        await server.close();

        expect(server.isRunning, isFalse);
        await expectLater(
          client.post(
            firstEndpoint.replace(path: '/execute'),
            headers: const <String, String>{'content-type': 'application/json'},
            body: jsonEncode(_buildRequest().toJson()),
          ),
          throwsA(isA<Exception>()),
        );

        await server.start();
        final restartedEndpoint = server.endpoint!;
        final restartedResponse = await client.post(
          restartedEndpoint.replace(path: '/execute'),
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(_buildRequest(vendorKey: 'hikvision').toJson()),
        );

        expect(server.isRunning, isTrue);
        expect(restartedResponse.statusCode, 200);
        final decoded =
            jsonDecode(restartedResponse.body) as Map<String, Object?>;
        expect(decoded['success'], true);
        expect(decoded['worker_label'], 'Fake Camera Worker');
      },
    );
  });

  group('UnsupportedOnyxAgentCameraBridgeServer', () {
    test('remains inert across start and close lifecycle calls', () async {
      const server = bridge_stub.UnsupportedOnyxAgentCameraBridgeServer();

      expect(server.isRunning, isFalse);
      expect(server.endpoint, isNull);

      await server.start();
      expect(server.isRunning, isFalse);
      expect(server.endpoint, isNull);

      await server.close();
      expect(server.isRunning, isFalse);
      expect(server.endpoint, isNull);
    });
  });
}

OnyxAgentCameraExecutionRequest _buildRequest({
  String vendorKey = 'generic_onvif',
}) {
  return OnyxAgentCameraExecutionRequest(
    packetId: 'CAM-PKT-BRIDGE-1',
    target: '10.55.8.14',
    clientId: 'CLIENT-MS-VALLEE',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    scopeLabel: 'CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE',
    incidentReference: 'INC-4451',
    sourceRouteLabel: 'Agent',
    approvedAtUtc: DateTime.utc(2026, 3, 27, 10, 12),
    executionPacket: OnyxAgentCameraExecutionPacket(
      packetId: 'CAM-PKT-BRIDGE-1',
      target: '10.55.8.14',
      vendorKey: vendorKey,
      vendorLabel: vendorKey == 'hikvision' ? 'Hikvision' : 'Generic ONVIF',
      profileKey: 'alarm_verification',
      profileLabel: 'Alarm Verification',
      onvifProfileToken: 'profile-1-main',
      mainStreamLabel: 'Main stream 4MP H.265',
      subStreamLabel: 'Substream 640x360',
      recorderTarget: 'NVR-4 / Channel 09',
      rollbackExportLabel: 'rollback-CAM-PKT-BRIDGE-1.json',
      credentialHandling: 'Use the stored digest-auth device profile.',
      changePlan: const <String>[
        'Load ONVIF media profile.',
        'Apply the approved stream preset.',
      ],
      verificationPlan: const <String>[
        'Open CCTV live view.',
        'Confirm recorder ingest.',
      ],
      rollbackPlan: const <String>['Restore the rollback export.'],
    ),
  );
}

class _FakeBridgeWorker extends OnyxAgentCameraVendorWorker {
  const _FakeBridgeWorker();

  @override
  String get vendorKey => 'hikvision';

  @override
  String get workerLabel => 'Fake Camera Worker';

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    return OnyxAgentCameraExecutionOutcome(
      success: true,
      providerLabel: 'local:test-camera-worker',
      detail: 'Fake worker accepted ${request.executionPacket.profileLabel}.',
      recommendedNextStep: 'Validate the bridge packet metadata.',
      remoteExecutionId: 'fake-exec-1',
      recordedAtUtc: DateTime.utc(2026, 4, 7, 12),
    );
  }
}
