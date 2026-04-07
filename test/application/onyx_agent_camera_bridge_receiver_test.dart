import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/dvr_http_auth.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_receiver.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_change_service.dart';

OnyxAgentCameraExecutionRequest _request({
  String vendorKey = 'hikvision',
  String vendorLabel = 'Hikvision',
  String profileKey = 'alarm_verification',
  String profileLabel = 'Alarm Verification',
  String target = '192.168.1.64',
}) {
  return OnyxAgentCameraExecutionRequest(
    packetId: 'CAM-PKT-900',
    target: target,
    clientId: 'CLIENT-001',
    siteId: 'SITE-SANDTON',
    scopeLabel: 'CLIENT-001 • SITE-SANDTON',
    incidentReference: 'INC-CTRL-42',
    sourceRouteLabel: 'CCTV',
    approvedAtUtc: DateTime.utc(2026, 3, 27, 9, 15),
    executionPacket: OnyxAgentCameraExecutionPacket(
      packetId: 'CAM-PKT-900',
      target: target,
      vendorKey: vendorKey,
      vendorLabel: vendorLabel,
      profileKey: profileKey,
      profileLabel: profileLabel,
      onvifProfileToken: 'onyx-hik-alarm-verification',
      mainStreamLabel: 'H.265 2560x1440 @ 18 fps / 3072 kbps',
      subStreamLabel: 'H.264 704x480 @ 10 fps / 512 kbps',
      recorderTarget: 'alarm_review_nvr',
      rollbackExportLabel: 'rollback-CAM-PKT-900-192-168-1-64.json',
      credentialHandling: 'Keep device credentials local.',
      changePlan: const <String>['Apply the approved profile.'],
      verificationPlan: const <String>['Confirm live view.'],
      rollbackPlan: const <String>['Restore the previous profile.'],
    ),
  );
}

void main() {
  group('OnyxAgentCameraBridgeReceiver', () {
    test('confirms a Hikvision change after device verification and read-back', () async {
      String? putBody;
      final client = MockClient((request) async {
        if (request.url.path == '/ISAPI/System/deviceInfo') {
          return http.Response('<DeviceInfo><deviceName>North Gate</deviceName></DeviceInfo>', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/ISAPI/Streaming/channels') {
          return http.Response(_channelListXml, 200);
        }
        if (request.method == 'PUT' &&
            request.url.path == '/ISAPI/Streaming/channels/101') {
          putBody = request.body;
          return http.Response('<ResponseStatus>OK</ResponseStatus>', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/ISAPI/Streaming/channels/101') {
          return http.Response(_verifiedChannelXml, 200);
        }
        return http.Response('not found', 404);
      });
      final receiver = OnyxAgentCameraBridgeReceiver(
        workers: const <OnyxAgentCameraVendorWorker>[],
        httpClient: client,
        resolveCredentials: (_, _) => const DvrHttpAuthConfig(
          mode: DvrHttpAuthMode.digest,
          username: 'operator',
          password: 'secret',
        ),
      );

      final outcome = await receiver.execute(_request());

      expect(outcome.success, isTrue);
      expect(outcome.providerLabel, 'local:camera-worker:hikvision');
      expect(outcome.detail, contains('Hikvision Camera Worker'));
      expect(outcome.detail, contains('channel 101'));
      expect(outcome.remoteExecutionId, contains('worker-hikvision-101'));
      expect(putBody, contains('<videoResolutionWidth>2560</videoResolutionWidth>'));
      expect(putBody, contains('<videoResolutionHeight>1440</videoResolutionHeight>'));
      expect(putBody, contains('<maxFrameRate>18</maxFrameRate>'));
      expect(putBody, contains('<constantBitRate>3072</constantBitRate>'));
    });

    test('returns success false when Hikvision auth fails', () async {
      var deviceInfoCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/ISAPI/System/deviceInfo') {
          deviceInfoCalls += 1;
          if (deviceInfoCalls == 1) {
            return http.Response(
              '',
              401,
              headers: const <String, String>{
                'www-authenticate':
                    'Digest realm="Hikvision", nonce="nonce123", qop="auth"',
              },
            );
          }
          expect(request.headers['Authorization'], startsWith('Digest '));
          return http.Response('unauthorized', 401);
        }
        return http.Response('not found', 404);
      });
      final receiver = OnyxAgentCameraBridgeReceiver(
        workers: const <OnyxAgentCameraVendorWorker>[],
        httpClient: client,
        resolveCredentials: (_, _) => const DvrHttpAuthConfig(
          mode: DvrHttpAuthMode.digest,
          username: 'operator',
          password: 'wrong-secret',
        ),
      );

      final outcome = await receiver.execute(_request());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('device verification failed'));
      expect(outcome.detail, contains('HTTP 401'));
    });

    test('returns success false when the device is unreachable', () async {
      final client = MockClient((request) async {
        throw http.ClientException('connection refused', request.url);
      });
      final receiver = OnyxAgentCameraBridgeReceiver(
        workers: const <OnyxAgentCameraVendorWorker>[],
        httpClient: client,
        resolveCredentials: (_, _) => const DvrHttpAuthConfig(
          mode: DvrHttpAuthMode.digest,
          username: 'operator',
          password: 'secret',
        ),
      );

      final outcome = await receiver.execute(_request());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('connection refused'));
      expect(outcome.detail, contains('failed before the change could be confirmed'));
    });

    test('returns success false when Hikvision read-back does not confirm the change', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/ISAPI/System/deviceInfo') {
          return http.Response('<DeviceInfo><deviceName>North Gate</deviceName></DeviceInfo>', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/ISAPI/Streaming/channels') {
          return http.Response(_channelListXml, 200);
        }
        if (request.method == 'PUT' &&
            request.url.path == '/ISAPI/Streaming/channels/101') {
          return http.Response('<ResponseStatus>OK</ResponseStatus>', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/ISAPI/Streaming/channels/101') {
          return http.Response(_unconfirmedChannelXml, 200);
        }
        return http.Response('not found', 404);
      });
      final receiver = OnyxAgentCameraBridgeReceiver(
        workers: const <OnyxAgentCameraVendorWorker>[],
        httpClient: client,
        resolveCredentials: (_, _) => const DvrHttpAuthConfig(
          mode: DvrHttpAuthMode.digest,
          username: 'operator',
          password: 'secret',
        ),
      );

      final outcome = await receiver.execute(_request());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('did not confirm Alarm Verification'));
      expect(outcome.detail, contains('maxFrameRate=12'));
    });

    test('falls back to the generic worker for unknown vendors and stays staged', () async {
      const receiver = OnyxAgentCameraBridgeReceiver();

      final outcome = await receiver.execute(
        _request(
          vendorKey: 'unknown_vendor',
          vendorLabel: 'Unknown Vendor',
          profileKey: 'balanced_monitoring',
          profileLabel: 'Balanced Monitoring',
        ),
      );

      expect(outcome.success, isFalse);
      expect(outcome.providerLabel, 'local:camera-worker:generic_onvif');
      expect(outcome.detail, contains('Camera control in staging mode'));
      expect(outcome.detail, contains('Balanced Monitoring'));
    });

    test('handles execution json and returns worker plus packet metadata', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/ISAPI/System/deviceInfo') {
          return http.Response('<DeviceInfo><deviceName>North Gate</deviceName></DeviceInfo>', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/ISAPI/Streaming/channels') {
          return http.Response(_channelListXml, 200);
        }
        if (request.method == 'PUT' &&
            request.url.path == '/ISAPI/Streaming/channels/101') {
          return http.Response('<ResponseStatus>OK</ResponseStatus>', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/ISAPI/Streaming/channels/101') {
          return http.Response(_verifiedChannelXml, 200);
        }
        return http.Response('not found', 404);
      });
      final receiver = OnyxAgentCameraBridgeReceiver(
        workers: const <OnyxAgentCameraVendorWorker>[],
        httpClient: client,
        resolveCredentials: (_, _) => const DvrHttpAuthConfig(
          mode: DvrHttpAuthMode.digest,
          username: 'operator',
          password: 'secret',
        ),
      );

      final response = await receiver.handleExecutionJson(
        _request().toJson(),
      );

      expect(response['success'], true);
      expect(response['provider_label'], 'local:camera-worker:hikvision');
      expect(response['worker_label'], 'Hikvision Camera Worker');
      expect(response['execution_packet'], isA<Map>());
      final packet = response['execution_packet']! as Map<String, Object?>;
      expect(packet['vendor_label'], 'Hikvision');
      expect(packet['profile_label'], 'Alarm Verification');
    });

    test('returns a structured failure when json is invalid', () async {
      const receiver = OnyxAgentCameraBridgeReceiver();

      final response = await receiver.handleExecutionJson(
        const <String, Object?>{'packet_id': 'CAM-PKT-1'},
      );

      expect(response['success'], false);
      expect(response['detail'], contains('The execution packet was invalid'));
      expect(response['provider_label'], 'local:camera-bridge-receiver');
    });
  });
}

const String _channelListXml = '''
<StreamingChannelList>
  <StreamingChannel>
    <id>101</id>
    <videoResolutionWidth>1280</videoResolutionWidth>
    <videoResolutionHeight>720</videoResolutionHeight>
    <maxFrameRate>12</maxFrameRate>
    <constantBitRate>1024</constantBitRate>
  </StreamingChannel>
</StreamingChannelList>
''';

const String _verifiedChannelXml = '''
<StreamingChannel>
  <id>101</id>
  <videoResolutionWidth>2560</videoResolutionWidth>
  <videoResolutionHeight>1440</videoResolutionHeight>
  <maxFrameRate>18</maxFrameRate>
  <constantBitRate>3072</constantBitRate>
</StreamingChannel>
''';

const String _unconfirmedChannelXml = '''
<StreamingChannel>
  <id>101</id>
  <videoResolutionWidth>2560</videoResolutionWidth>
  <videoResolutionHeight>1440</videoResolutionHeight>
  <maxFrameRate>12</maxFrameRate>
  <constantBitRate>3072</constantBitRate>
</StreamingChannel>
''';
