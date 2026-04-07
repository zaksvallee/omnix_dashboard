import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_runner_service.dart';

void main() {
  test(
    'runs preflight from payload files and writes report plus rollout artifacts',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'hik-connect-preflight-runner-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));

      final cameraPath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultCameraFileName}';
      final alarmPath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultAlarmFileName}';
      final livePath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultLiveFileName}';
      final playbackPath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultPlaybackFileName}';
      final downloadPath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultVideoDownloadFileName}';
      final reportPath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultReportFileName}';
      final reportJsonPath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultReportJsonFileName}';
      final scopeSeedPath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultScopeSeedFileName}';
      final pilotEnvPath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultPilotEnvFileName}';
      final bootstrapPacketPath =
          '${directory.path}/${HikConnectPayloadBundleLocator.defaultBootstrapPacketFileName}';

      await File(cameraPath).writeAsString(
        '''
      {
        "pages": [
          {
            "errorCode": "0",
            "data": {
              "totalCount": 1,
              "pageIndex": 1,
              "pageSize": 200,
              "cameraInfo": [
                {
                  "resourceId": "camera-front",
                  "cameraName": "Front Yard",
                  "deviceSerialNo": "SERIAL-001",
                  "areaName": "MS Vallee Residence"
                }
              ]
            }
          }
        ]
      }
      ''',
      );
      await File(alarmPath).writeAsString(
        '''
      {
        "data": {
          "batchId": "batch-001",
          "alarmMsg": [
            {
              "guid": "hik-guid-1",
              "msgType": "1",
              "alarmState": "1",
              "alarmSubCategory": "alarmSubCategoryCamera",
              "timeInfo": {
                "startTime": "2026-03-30T00:10:00Z"
              },
              "eventSource": {
                "sourceId": "camera-front",
                "sourceName": "Front Yard",
                "areaName": "MS Vallee Residence",
                "eventType": "100657",
                "deviceName": "G95721825"
              },
              "alarmRule": {
                "name": "People Queue Leave"
              },
              "anprInfo": {
                "licensePlate": "CA123456"
              },
              "fileInfo": {
                "files": [
                  {
                    "type": "1",
                    "fileUrl": "https://files.example.com/snapshot.jpg"
                  }
                ]
              }
            }
          ]
        }
      }
      ''',
      );
      await File(livePath).writeAsString(
        '''
      {
        "errorCode": "0",
        "data": {
          "url": "wss://stream.example.com/live/token"
        }
      }
      ''',
      );
      await File(playbackPath).writeAsString(
        '''
      {
        "errorCode": "0",
        "data": {
          "totalCount": 1,
          "pageIndex": 1,
          "pageSize": 50,
          "recordList": [
            {
              "recordId": "record-001",
              "beginTime": "2026-03-30T00:00:00Z",
              "endTime": "2026-03-30T00:05:00Z",
              "playbackUrl": "https://stream.example.com/playback/record-001"
            }
          ]
        }
      }
      ''',
      );
      await File(downloadPath).writeAsString(
        '''
      {
        "errorCode": "0",
        "data": {
          "downloadUrl": "https://stream.example.com/download/video.mp4"
        }
      }
      ''',
      );

      const runner = HikConnectPreflightRunnerService();
      final result = await runner.run(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        apiBaseUrl: 'https://api.hik-connect.example.com',
        provider: 'hik_connect_openapi',
        appKey: 'app-key-001',
        appSecret: 'app-secret-001',
        areaId: 'AREA-001',
        includeSubArea: false,
        alarmEventTypes: const <int>[100657, 42],
        cameraLabels: const <String, String>{
          'camera-front': 'Front Gate',
        },
        cameraPayloadPath: cameraPath,
        alarmPayloadPath: alarmPath,
        liveAddressPayloadPath: livePath,
        playbackPayloadPath: playbackPath,
        videoDownloadPayloadPath: downloadPath,
        reportOutputPath: reportPath,
        reportJsonOutputPath: reportJsonPath,
        scopeSeedOutputPath: scopeSeedPath,
        pilotEnvOutputPath: pilotEnvPath,
        bootstrapPacketOutputPath: bootstrapPacketPath,
      );

      expect(result.report, contains('HIK-CONNECT PREFLIGHT REPORT'));
      expect(result.report, contains('Camera Bootstrap'));
      expect(result.report, contains('Front Gate'));
      expect(result.report, contains('Alarm Smoke'));
      expect(result.report, contains('Video Smoke'));
      expect(result.report, contains('Rollout Artifacts'));
      expect(result.report, contains('scope seed: $scopeSeedPath'));
      expect(result.report, contains('pilot env: $pilotEnvPath'));
      expect(
        result.report,
        contains('bootstrap packet: $bootstrapPacketPath'),
      );
      expect(result.report, contains('Rollout Readiness'));
      expect(result.scopeSeedOutputPath, scopeSeedPath);
      expect(result.pilotEnvOutputPath, pilotEnvPath);
      expect(result.bootstrapPacketOutputPath, bootstrapPacketPath);

      final savedReport = File(reportPath).readAsStringSync();
      expect(savedReport, contains('Payload Inventory'));

      final savedJson = jsonDecode(
        File(reportJsonPath).readAsStringSync(),
      ) as Map<String, Object?>;
      expect(savedJson['client_id'], 'CLIENT-MS-VALLEE');
      expect(
        (savedJson['rollout_readiness'] ?? '').toString(),
        contains('camera bootstrap ready'),
      );
      expect(
        savedJson['rollout_artifacts'],
        <Map<String, Object?>>[
          <String, Object?>{
            'key': 'scope_seed',
            'label': 'scope seed',
            'status': 'saved',
            'path': scopeSeedPath,
          },
          <String, Object?>{
            'key': 'pilot_env',
            'label': 'pilot env',
            'status': 'saved',
            'path': pilotEnvPath,
          },
          <String, Object?>{
            'key': 'bootstrap_packet',
            'label': 'bootstrap packet',
            'status': 'saved',
            'path': bootstrapPacketPath,
          },
        ],
      );

      final savedScopeSeed = File(scopeSeedPath).readAsStringSync();
      expect(savedScopeSeed, contains('"provider": "hik_connect_openapi"'));
      expect(savedScopeSeed, contains('"app_key": "app-key-001"'));
      expect(savedScopeSeed, contains('"area_id": "AREA-001"'));
      expect(savedScopeSeed, contains('"alarm_event_types": ['));
      expect(savedScopeSeed, contains('"device_serial_no": "SERIAL-001"'));
      expect(savedScopeSeed, contains('"camera-front": "Front Gate"'));

      final savedPilotEnv = File(pilotEnvPath).readAsStringSync();
      expect(savedPilotEnv, contains("export ONYX_DVR_APP_KEY='app-key-001'"));
      expect(savedPilotEnv, contains('export ONYX_DVR_INCLUDE_SUB_AREA=false'));
      expect(
        savedPilotEnv,
        contains("export ONYX_DVR_DEVICE_SERIAL_NO='SERIAL-001'"),
      );

      final savedBootstrapPacket = File(
        bootstrapPacketPath,
      ).readAsStringSync();
      expect(savedBootstrapPacket, contains('HIK-CONNECT BOOTSTRAP PACKET'));
      expect(savedBootstrapPacket, contains('Front Gate [camera-front]'));
      expect(savedBootstrapPacket, contains('Pilot Env Block'));
    },
  );
}
