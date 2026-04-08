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
    sourceRouteLabel: 'AI Queue',
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
    test(
      'confirms a Hikvision change after device verification and read-back',
      () async {
        String? putBody;
        final client = MockClient((request) async {
          if (request.url.path == '/ISAPI/System/deviceInfo') {
            return http.Response(
              '<DeviceInfo><deviceName>North Gate</deviceName></DeviceInfo>',
              200,
            );
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
        expect(
          putBody,
          contains('<videoResolutionWidth>2560</videoResolutionWidth>'),
        );
        expect(
          putBody,
          contains('<videoResolutionHeight>1440</videoResolutionHeight>'),
        );
        expect(putBody, contains('<maxFrameRate>18</maxFrameRate>'));
        expect(putBody, contains('<constantBitRate>3072</constantBitRate>'));
      },
    );

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
      expect(
        outcome.detail,
        contains('failed before the change could be confirmed'),
      );
    });

    test(
      'returns success false when Hikvision read-back does not confirm the change',
      () async {
        final client = MockClient((request) async {
          if (request.url.path == '/ISAPI/System/deviceInfo') {
            return http.Response(
              '<DeviceInfo><deviceName>North Gate</deviceName></DeviceInfo>',
              200,
            );
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
      },
    );

    test(
      'falls back to the generic worker for unknown vendors and stays staged',
      () async {
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
      },
    );

    test(
      'handles execution json and returns worker plus packet metadata',
      () async {
        final client = MockClient((request) async {
          if (request.url.path == '/ISAPI/System/deviceInfo') {
            return http.Response(
              '<DeviceInfo><deviceName>North Gate</deviceName></DeviceInfo>',
              200,
            );
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
      },
    );

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

  group('DahuaOnyxAgentCameraWorker', () {
    OnyxAgentCameraExecutionRequest dahuaRequest({
      String target = '192.168.1.80',
      String mainStreamLabel = 'H.265 2560x1440 @ 18 fps / 3072 kbps',
    }) {
      return OnyxAgentCameraExecutionRequest(
        packetId: 'CAM-PKT-901',
        target: target,
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        scopeLabel: 'CLIENT-001 • SITE-SANDTON',
        incidentReference: 'INC-CTRL-43',
        sourceRouteLabel: 'AI Queue',
        approvedAtUtc: DateTime.utc(2026, 3, 28, 9, 0),
        executionPacket: OnyxAgentCameraExecutionPacket(
          packetId: 'CAM-PKT-901',
          target: target,
          vendorKey: 'dahua',
          vendorLabel: 'Dahua',
          profileKey: 'alarm_verification',
          profileLabel: 'Alarm Verification',
          onvifProfileToken: 'onyx-dahua-alarm-verification',
          mainStreamLabel: mainStreamLabel,
          subStreamLabel: 'H.264 704x480 @ 10 fps / 512 kbps',
          recorderTarget: 'alarm_review_nvr',
          rollbackExportLabel: 'rollback-CAM-PKT-901-192-168-1-80.json',
          credentialHandling: 'Keep device credentials local.',
          changePlan: const <String>['Apply the approved profile.'],
          verificationPlan: const <String>['Confirm live view.'],
          rollbackPlan: const <String>['Restore the previous profile.'],
        ),
      );
    }

    const creds = DvrHttpAuthConfig(
      mode: DvrHttpAuthMode.digest,
      username: 'admin',
      password: 'secret',
    );

    OnyxAgentCameraBridgeReceiver receiverWith(http.Client client) {
      return OnyxAgentCameraBridgeReceiver(
        workers: const <OnyxAgentCameraVendorWorker>[],
        httpClient: client,
        resolveCredentials: (_, _) => creds,
      );
    }

    test('confirms a Dahua change after device verification and read-back',
        () async {
      String? postBody;
      final client = MockClient((request) async {
        if (request.url.path == '/cgi-bin/magicBox.cgi') {
          return http.Response('table.DeviceType=IPC-HDW\r\n', 200);
        }
        if (request.url.path == '/cgi-bin/configManager.cgi' &&
            request.method == 'GET') {
          return http.Response(_dahuaEncodeConfig, 200);
        }
        if (request.url.path == '/cgi-bin/configManager.cgi' &&
            request.method == 'POST') {
          postBody = request.body;
          return http.Response('OK\r\n', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await receiverWith(client).execute(dahuaRequest());

      expect(outcome.success, isTrue);
      expect(outcome.providerLabel, 'local:camera-worker:dahua');
      expect(outcome.detail, contains('Dahua Camera Worker'));
      expect(outcome.detail, contains('Encode[0]'));
      expect(outcome.remoteExecutionId, contains('worker-dahua-encode0'));
      final encWidth = Uri.encodeQueryComponent('Encode[0].MainFormat[0].Video.Width');
      final encHeight = Uri.encodeQueryComponent('Encode[0].MainFormat[0].Video.Height');
      final encFps = Uri.encodeQueryComponent('Encode[0].MainFormat[0].Video.FPS');
      final encBitrate = Uri.encodeQueryComponent('Encode[0].MainFormat[0].Video.BitRate');
      expect(postBody, contains('action=setConfig'));
      expect(postBody, contains('$encWidth=2560'));
      expect(postBody, contains('$encHeight=1440'));
      expect(postBody, contains('$encFps=18'));
      expect(postBody, contains('$encBitrate=3072'));
    });

    test('returns staging outcome when credentials are not configured',
        () async {
      const worker = DahuaOnyxAgentCameraWorker(
        credentials: DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
      );
      final outcome = await worker.execute(dahuaRequest());

      expect(outcome.success, isFalse);
      expect(outcome.providerLabel, 'local:camera-worker:dahua');
      expect(outcome.detail, contains('staging mode'));
    });

    test('returns failure when device info endpoint is unreachable', () async {
      final client = MockClient((request) async {
        throw http.ClientException('connection refused', request.url);
      });

      final outcome = await receiverWith(client).execute(dahuaRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('failed before the change could be confirmed'));
    });

    test('returns failure when device info returns non-200', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/cgi-bin/magicBox.cgi') {
          return http.Response('', 401);
        }
        return http.Response('not found', 404);
      });

      final outcome = await receiverWith(client).execute(dahuaRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('device verification failed'));
      expect(outcome.detail, contains('HTTP 401'));
    });

    test('returns failure when channel discovery finds no Encode[0]', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/cgi-bin/magicBox.cgi') {
          return http.Response('table.DeviceType=IPC-HDW\r\n', 200);
        }
        if (request.url.path == '/cgi-bin/configManager.cgi') {
          return http.Response('Error=NoData\r\n', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await receiverWith(client).execute(dahuaRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('no writable Encode[0] channel'));
    });

    test('returns failure when POST config write is rejected', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/cgi-bin/magicBox.cgi') {
          return http.Response('table.DeviceType=IPC-HDW\r\n', 200);
        }
        if (request.url.path == '/cgi-bin/configManager.cgi' &&
            request.method == 'GET') {
          return http.Response(_dahuaEncodeConfig, 200);
        }
        if (request.url.path == '/cgi-bin/configManager.cgi' &&
            request.method == 'POST') {
          return http.Response('Error=PermissionDenied\r\n', 403);
        }
        return http.Response('not found', 404);
      });

      final outcome = await receiverWith(client).execute(dahuaRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('rejected the Encode[0] configuration update'));
      expect(outcome.detail, contains('HTTP 403'));
    });

    test('returns failure when read-back does not confirm the change', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/cgi-bin/magicBox.cgi') {
          return http.Response('table.DeviceType=IPC-HDW\r\n', 200);
        }
        if (request.url.path == '/cgi-bin/configManager.cgi' &&
            request.method == 'GET') {
          // Return stale values on both discovery and read-back.
          return http.Response(_dahuaEncodeConfigStale, 200);
        }
        if (request.url.path == '/cgi-bin/configManager.cgi' &&
            request.method == 'POST') {
          return http.Response('OK\r\n', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await receiverWith(client).execute(dahuaRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('did not confirm Alarm Verification'));
      expect(
        outcome.detail,
        contains('Encode[0].MainFormat[0].Video.Width'),
      );
    });

    test('falls back to default preset when mainStreamLabel is unparseable',
        () async {
      String? postBody;
      final client = MockClient((request) async {
        if (request.url.path == '/cgi-bin/magicBox.cgi') {
          return http.Response('table.DeviceType=IPC-HDW\r\n', 200);
        }
        if (request.url.path == '/cgi-bin/configManager.cgi' &&
            request.method == 'GET') {
          return http.Response(_dahuaEncodeConfigDefault, 200);
        }
        if (request.url.path == '/cgi-bin/configManager.cgi' &&
            request.method == 'POST') {
          postBody = request.body;
          return http.Response('OK\r\n', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await receiverWith(client).execute(
        dahuaRequest(mainStreamLabel: 'no resolution here'),
      );

      final encWidth = Uri.encodeQueryComponent('Encode[0].MainFormat[0].Video.Width');
      expect(outcome.success, isTrue);
      expect(postBody, contains('$encWidth=1920'));
    });
  });

  group('AxisOnyxAgentCameraWorker', () {
    OnyxAgentCameraExecutionRequest axisRequest({
      String target = '192.168.1.90',
      String mainStreamLabel = 'H.265 2560x1440 @ 18 fps / 3072 kbps',
    }) {
      return OnyxAgentCameraExecutionRequest(
        packetId: 'CAM-PKT-902',
        target: target,
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        scopeLabel: 'CLIENT-001 • SITE-SANDTON',
        incidentReference: 'INC-CTRL-44',
        sourceRouteLabel: 'AI Queue',
        approvedAtUtc: DateTime.utc(2026, 3, 29, 9, 0),
        executionPacket: OnyxAgentCameraExecutionPacket(
          packetId: 'CAM-PKT-902',
          target: target,
          vendorKey: 'axis',
          vendorLabel: 'Axis',
          profileKey: 'alarm_verification',
          profileLabel: 'Alarm Verification',
          onvifProfileToken: 'onyx-axis-alarm-verification',
          mainStreamLabel: mainStreamLabel,
          subStreamLabel: 'H.264 704x480 @ 10 fps / 512 kbps',
          recorderTarget: 'alarm_review_nvr',
          rollbackExportLabel: 'rollback-CAM-PKT-902-192-168-1-90.json',
          credentialHandling: 'Keep device credentials local.',
          changePlan: const <String>['Apply the approved profile.'],
          verificationPlan: const <String>['Confirm live view.'],
          rollbackPlan: const <String>['Restore the previous profile.'],
        ),
      );
    }

    const axisCreds = DvrHttpAuthConfig(
      mode: DvrHttpAuthMode.digest,
      username: 'admin',
      password: 'secret',
    );

    OnyxAgentCameraBridgeReceiver axisReceiverWith(http.Client client) {
      return OnyxAgentCameraBridgeReceiver(
        workers: const <OnyxAgentCameraVendorWorker>[],
        httpClient: client,
        resolveCredentials: (_, _) => axisCreds,
      );
    }

    test('confirms an Axis change after device verification and read-back',
        () async {
      String? postBody;
      final client = MockClient((request) async {
        if (request.url.path == '/axis-cgi/basicdeviceinfo.cgi') {
          return http.Response(
            '{"apiVersion":"1.0","data":{"propertyList":{"ProdNbr":"P3245-V"}}}',
            200,
          );
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'GET') {
          return http.Response(_axisParamConfig, 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'POST') {
          postBody = request.body;
          return http.Response('OK', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await axisReceiverWith(client).execute(axisRequest());

      expect(outcome.success, isTrue);
      expect(outcome.providerLabel, 'local:camera-worker:axis');
      expect(outcome.detail, contains('Axis Camera Worker'));
      expect(outcome.detail, contains('Image.I0'));
      expect(outcome.remoteExecutionId, contains('worker-axis-image0'));
      final encRes = Uri.encodeQueryComponent('Image.I0.Resolution');
      final encFps = Uri.encodeQueryComponent('Image.I0.FPS');
      expect(postBody, contains('action=update'));
      expect(postBody, contains('$encRes=2560x1440'));
      expect(postBody, contains('$encFps=18'));
    });

    test('returns staging outcome when credentials are not configured',
        () async {
      const worker = AxisOnyxAgentCameraWorker(
        credentials: DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
      );
      final outcome = await worker.execute(axisRequest());

      expect(outcome.success, isFalse);
      expect(outcome.providerLabel, 'local:camera-worker:axis');
      expect(outcome.detail, contains('staging mode'));
    });

    test('returns failure when device info endpoint is unreachable', () async {
      final client = MockClient((request) async {
        throw http.ClientException('connection refused', request.url);
      });

      final outcome = await axisReceiverWith(client).execute(axisRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('failed before the change could be confirmed'));
    });

    test('returns failure when basicdeviceinfo returns non-200', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/axis-cgi/basicdeviceinfo.cgi') {
          return http.Response('', 401);
        }
        return http.Response('not found', 404);
      });

      final outcome = await axisReceiverWith(client).execute(axisRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('device verification failed'));
      expect(outcome.detail, contains('HTTP 401'));
    });

    test('returns failure when channel discovery finds no Image.I0', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/axis-cgi/basicdeviceinfo.cgi') {
          return http.Response('{"data":{}}', 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'GET') {
          return http.Response('Error=No such group', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await axisReceiverWith(client).execute(axisRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('no writable Image.I0 channel'));
    });

    test('returns failure when POST write is rejected with non-200', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/axis-cgi/basicdeviceinfo.cgi') {
          return http.Response('{"data":{}}', 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'GET') {
          return http.Response(_axisParamConfig, 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'POST') {
          return http.Response('Access denied', 403);
        }
        return http.Response('not found', 404);
      });

      final outcome = await axisReceiverWith(client).execute(axisRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('rejected the Image.I0 configuration update'));
      expect(outcome.detail, contains('HTTP 403'));
    });

    test('returns failure when POST response is not OK', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/axis-cgi/basicdeviceinfo.cgi') {
          return http.Response('{"data":{}}', 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'GET') {
          return http.Response(_axisParamConfig, 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'POST') {
          return http.Response('Error=unsupported param', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await axisReceiverWith(client).execute(axisRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('did not return OK'));
    });

    test('returns failure when read-back does not confirm the change', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/axis-cgi/basicdeviceinfo.cgi') {
          return http.Response('{"data":{}}', 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'GET') {
          return http.Response(_axisParamConfigStale, 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'POST') {
          return http.Response('OK', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await axisReceiverWith(client).execute(axisRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('did not confirm Alarm Verification'));
      expect(outcome.detail, contains('Image.I0.Resolution'));
    });

    test('falls back to default preset when mainStreamLabel is unparseable',
        () async {
      String? postBody;
      final client = MockClient((request) async {
        if (request.url.path == '/axis-cgi/basicdeviceinfo.cgi') {
          return http.Response('{"data":{}}', 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'GET') {
          return http.Response(_axisParamConfigDefault, 200);
        }
        if (request.url.path == '/axis-cgi/param.cgi' &&
            request.method == 'POST') {
          postBody = request.body;
          return http.Response('OK', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await axisReceiverWith(client).execute(
        axisRequest(mainStreamLabel: 'no resolution here'),
      );

      final encRes = Uri.encodeQueryComponent('Image.I0.Resolution');
      expect(outcome.success, isTrue);
      expect(postBody, contains('$encRes=1920x1080'));
    });
  });

  group('UniviewOnyxAgentCameraWorker', () {
    OnyxAgentCameraExecutionRequest univiewRequest({
      String target = '192.168.1.95',
      String mainStreamLabel = 'H.265 2560x1440 @ 18 fps / 3072 kbps',
    }) {
      return OnyxAgentCameraExecutionRequest(
        packetId: 'CAM-PKT-903',
        target: target,
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        scopeLabel: 'CLIENT-001 • SITE-SANDTON',
        incidentReference: 'INC-CTRL-45',
        sourceRouteLabel: 'AI Queue',
        approvedAtUtc: DateTime.utc(2026, 3, 30, 9, 0),
        executionPacket: OnyxAgentCameraExecutionPacket(
          packetId: 'CAM-PKT-903',
          target: target,
          vendorKey: 'uniview',
          vendorLabel: 'Uniview',
          profileKey: 'alarm_verification',
          profileLabel: 'Alarm Verification',
          onvifProfileToken: 'onyx-uniview-alarm-verification',
          mainStreamLabel: mainStreamLabel,
          subStreamLabel: 'H.264 704x480 @ 10 fps / 512 kbps',
          recorderTarget: 'alarm_review_nvr',
          rollbackExportLabel: 'rollback-CAM-PKT-903-192-168-1-95.json',
          credentialHandling: 'Keep device credentials local.',
          changePlan: const <String>['Apply the approved profile.'],
          verificationPlan: const <String>['Confirm live view.'],
          rollbackPlan: const <String>['Restore the previous profile.'],
        ),
      );
    }

    const univiewCreds = DvrHttpAuthConfig(
      mode: DvrHttpAuthMode.digest,
      username: 'admin',
      password: 'secret',
    );

    OnyxAgentCameraBridgeReceiver univiewReceiverWith(http.Client client) {
      return OnyxAgentCameraBridgeReceiver(
        workers: const <OnyxAgentCameraVendorWorker>[],
        httpClient: client,
        resolveCredentials: (_, _) => univiewCreds,
      );
    }

    test('confirms a Uniview change after device verification and read-back',
        () async {
      String? putBody;
      final client = MockClient((request) async {
        if (request.url.path == '/LAPI/V1.0/System/DeviceInfo') {
          return http.Response(_univiewDeviceInfo, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'GET') {
          return http.Response(_univiewMainstreamConfig, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'PUT') {
          putBody = request.body;
          return http.Response(_univiewWriteOk, 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await univiewReceiverWith(client).execute(univiewRequest());

      expect(outcome.success, isTrue);
      expect(outcome.providerLabel, 'local:camera-worker:uniview');
      expect(outcome.detail, contains('Uniview Camera Worker'));
      expect(outcome.detail, contains('Mainstream'));
      expect(outcome.remoteExecutionId, contains('worker-uniview-mainstream'));
      expect(putBody, contains('2560*1440'));
      expect(putBody, contains('"FrameRate":18'));
    });

    test('returns staging outcome when credentials are not configured',
        () async {
      const worker = UniviewOnyxAgentCameraWorker(
        credentials: DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
      );
      final outcome = await worker.execute(univiewRequest());

      expect(outcome.success, isFalse);
      expect(outcome.providerLabel, 'local:camera-worker:uniview');
      expect(outcome.detail, contains('staging mode'));
    });

    test('returns failure when device info endpoint is unreachable', () async {
      final client = MockClient((request) async {
        throw http.ClientException('connection refused', request.url);
      });

      final outcome = await univiewReceiverWith(client).execute(univiewRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('failed before the change could be confirmed'));
    });

    test('returns failure when DeviceInfo returns non-200', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/LAPI/V1.0/System/DeviceInfo') {
          return http.Response('', 401);
        }
        return http.Response('not found', 404);
      });

      final outcome = await univiewReceiverWith(client).execute(univiewRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('device verification failed'));
      expect(outcome.detail, contains('HTTP 401'));
    });

    test('returns failure when channel discovery finds no VideoEncodeParam',
        () async {
      final client = MockClient((request) async {
        if (request.url.path == '/LAPI/V1.0/System/DeviceInfo') {
          return http.Response(_univiewDeviceInfo, 200);
        }
        if (request.url.path ==
            '/LAPI/V1.0/Channels/0/Media/Video/Mainstream') {
          return http.Response('{"Response":{"StatusCode":1,"StatusString":"Not found"}}', 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await univiewReceiverWith(client).execute(univiewRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('no readable Mainstream channel'));
    });

    test('returns failure when PUT config write is rejected', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/LAPI/V1.0/System/DeviceInfo') {
          return http.Response(_univiewDeviceInfo, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'GET') {
          return http.Response(_univiewMainstreamConfig, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'PUT') {
          return http.Response('', 403);
        }
        return http.Response('not found', 404);
      });

      final outcome = await univiewReceiverWith(client).execute(univiewRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('rejected the Mainstream configuration update'));
      expect(outcome.detail, contains('HTTP 403'));
    });

    test('returns failure when PUT response does not confirm success', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/LAPI/V1.0/System/DeviceInfo') {
          return http.Response(_univiewDeviceInfo, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'GET') {
          return http.Response(_univiewMainstreamConfig, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'PUT') {
          return http.Response(
            '{"Response":{"StatusCode":5,"StatusString":"PermissionDenied"}}',
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final outcome = await univiewReceiverWith(client).execute(univiewRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('did not confirm the Mainstream update'));
    });

    test('returns failure when read-back does not confirm the change', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/LAPI/V1.0/System/DeviceInfo') {
          return http.Response(_univiewDeviceInfo, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'GET') {
          // Return stale values on both discovery and read-back.
          return http.Response(_univiewMainstreamConfigStale, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'PUT') {
          return http.Response(_univiewWriteOk, 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await univiewReceiverWith(client).execute(univiewRequest());

      expect(outcome.success, isFalse);
      expect(outcome.detail, contains('did not confirm Alarm Verification'));
      expect(outcome.detail, contains('VideoEncodeParam.Resolution'));
    });

    test('falls back to default preset when mainStreamLabel is unparseable',
        () async {
      String? putBody;
      final client = MockClient((request) async {
        if (request.url.path == '/LAPI/V1.0/System/DeviceInfo') {
          return http.Response(_univiewDeviceInfo, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'GET') {
          return http.Response(_univiewMainstreamConfigDefault, 200);
        }
        if (request.url.path ==
                '/LAPI/V1.0/Channels/0/Media/Video/Mainstream' &&
            request.method == 'PUT') {
          putBody = request.body;
          return http.Response(_univiewWriteOk, 200);
        }
        return http.Response('not found', 404);
      });

      final outcome = await univiewReceiverWith(client).execute(
        univiewRequest(mainStreamLabel: 'no resolution here'),
      );

      expect(outcome.success, isTrue);
      expect(putBody, contains('1920*1080'));
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

// ─── Dahua fixtures ───────────────────────────────────────────────────────────

// Verified response — values match the 2560×1440@18fps/3072kbps preset.
const String _dahuaEncodeConfig = '''
table.Encode[0].MainFormat[0].Video.Width=2560
table.Encode[0].MainFormat[0].Video.Height=1440
table.Encode[0].MainFormat[0].Video.FPS=18
table.Encode[0].MainFormat[0].Video.BitRate=3072
table.Encode[0].MainFormat[0].Video.Compression=H.265
''';

// Stale response — old values, mismatch expected after write.
const String _dahuaEncodeConfigStale = '''
table.Encode[0].MainFormat[0].Video.Width=1280
table.Encode[0].MainFormat[0].Video.Height=720
table.Encode[0].MainFormat[0].Video.FPS=12
table.Encode[0].MainFormat[0].Video.BitRate=1024
table.Encode[0].MainFormat[0].Video.Compression=H.264
''';

// Default response — values match the fallback 1920×1080@15fps/2048kbps preset.
const String _dahuaEncodeConfigDefault = '''
table.Encode[0].MainFormat[0].Video.Width=1920
table.Encode[0].MainFormat[0].Video.Height=1080
table.Encode[0].MainFormat[0].Video.FPS=15
table.Encode[0].MainFormat[0].Video.BitRate=2048
table.Encode[0].MainFormat[0].Video.Compression=H.265
''';

// ─── Axis fixtures ────────────────────────────────────────────────────────────

// Verified response — values match the 2560x1440@18fps preset.
const String _axisParamConfig = '''
root.Image.I0.Resolution=2560x1440
root.Image.I0.FPS=18
root.Image.I0.Compression=h265
''';

// Stale response — old values, will not match 2560x1440@18fps.
const String _axisParamConfigStale = '''
root.Image.I0.Resolution=1280x720
root.Image.I0.FPS=12
root.Image.I0.Compression=h264
''';

// Default response — values match 1920x1080@15fps fallback preset.
const String _axisParamConfigDefault = '''
root.Image.I0.Resolution=1920x1080
root.Image.I0.FPS=15
root.Image.I0.Compression=h265
''';

// ─── Uniview fixtures ─────────────────────────────────────────────────────────

const String _univiewDeviceInfo = '{"Response":{"StatusCode":0,"StatusString":"OK","DeviceInfo":{"DeviceType":"IPC"}}}';

// Verified response — values match 2560*1440@18fps/3072kbps preset.
const String _univiewMainstreamConfig = '{"Response":{"StatusCode":0,"StatusString":"OK","VideoEncodeParam":{"Resolution":"2560*1440","FrameRate":18,"BitRate":3072,"EncodeType":"H.265"}}}';

// Stale response — old values, will not match 2560*1440@18fps.
const String _univiewMainstreamConfigStale = '{"Response":{"StatusCode":0,"StatusString":"OK","VideoEncodeParam":{"Resolution":"1280*720","FrameRate":12,"BitRate":1024,"EncodeType":"H.264"}}}';

// Default response — values match 1920*1080@15fps/2048kbps fallback preset.
const String _univiewMainstreamConfigDefault = '{"Response":{"StatusCode":0,"StatusString":"OK","VideoEncodeParam":{"Resolution":"1920*1080","FrameRate":15,"BitRate":2048,"EncodeType":"H.265"}}}';

// Successful PUT response.
const String _univiewWriteOk = '{"Response":{"StatusCode":0,"StatusString":"OK"}}';
