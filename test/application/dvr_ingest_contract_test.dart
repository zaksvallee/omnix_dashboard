import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/dvr_ingest_contract.dart';

void main() {
  test('hikvision DVR fixture normalizes into shared video event contract', () {
    final fixture = File(
      'test/fixtures/dvr_hikvision_isapi_event_notification_alert_sample.json',
    ).readAsStringSync();
    final normalizer = DvrFixtureContractNormalizer(
      profile: DvrProviderProfile.hikvisionMonitorOnly,
      baseUri: Uri.parse('https://dvr.example.com'),
    );

    final contract = normalizer.normalize(
      payload: jsonDecode(fixture),
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(contract, isNotNull);
    expect(contract!.provider, 'hikvision_dvr_monitor_only');
    expect(contract.sourceType, 'dvr');
    expect(contract.externalId, 'DVR-EVT-1001');
    expect(contract.cameraId, 'channel-3');
    expect(contract.channelId, '3');
    expect(contract.zone, 'loading_bay');
    expect(contract.faceMatchId, 'PERSON-44');
    expect(contract.plateNumber, 'CA123456');
    expect(contract.headline, 'HIKVISION_DVR_MONITOR_ONLY LINE_CROSSING');
    expect(contract.buildSummary(), contains('channel:3'));
    expect(contract.buildSummary(), contains('snapshot:private-fetch'));
    expect(contract.buildSummary(), contains('clip:not_expected'));
    expect(contract.buildSummary(), isNot(contains('FR:PERSON-44')));
    expect(contract.buildSummary(), isNot(contains('LPR:CA123456')));
    expect(
      contract.evidence.snapshotUrl,
      'https://dvr.example.com/ISAPI/Streaming/channels/301/picture',
    );
    expect(contract.evidence.clipUrl, isNull);
    expect(contract.toNormalizedIntelRecord().sourceType, 'dvr');
    expect(contract.toNormalizedIntelRecord().faceMatchId, 'PERSON-44');
    expect(contract.toNormalizedIntelRecord().plateNumber, 'CA123456');
    expect(contract.toNormalizedIntelRecord().clipUrl, isNull);
  });

  test('generic DVR fixture normalizes into shared contract', () {
    final fixture = File(
      'test/fixtures/dvr_generic_event_sample.json',
    ).readAsStringSync();
    final normalizer = DvrFixtureContractNormalizer(
      profile: DvrProviderProfile.genericEventList,
      baseUri: Uri.parse('https://generic-dvr.example.com'),
    );

    final contract = normalizer.normalize(
      payload: jsonDecode(fixture),
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(contract, isNotNull);
    expect(contract!.provider, 'generic_dvr');
    expect(contract.externalId, 'GEN-DVR-7');
    expect(contract.cameraId, 'GEN-CAM-7');
    expect(contract.channelId, '7');
    expect(contract.zone, 'parking_north');
    expect(contract.objectLabel, 'vehicle');
    expect(contract.headline, 'GENERIC_DVR MOTION');
    expect(contract.buildSummary(), contains('snapshot:private-fetch'));
    expect(
      contract.toNormalizedIntelRecord().snapshotUrl,
      'https://generic-dvr.example.com/api/dvr/events/GEN-DVR-7/snapshot.jpg',
    );
  });

  test(
    'hikvision video loss fixture normalizes into a canonical video-loss contract',
    () {
      final normalizer = DvrFixtureContractNormalizer(
        profile: DvrProviderProfile.hikvisionMonitorOnly,
        baseUri: Uri.parse('https://dvr.example.com'),
      );

      final contract = normalizer.normalize(
        payload: {
          'EventNotificationAlert': {
            'UUID': 'DVR-EVT-VIDLOSS-11',
            'eventType': 'videoloss',
            'dateTime': '2026-03-13T10:25:00Z',
            'channelID': '11',
            'eventState': 'active',
          },
        },
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(contract, isNotNull);
      expect(contract!.provider, 'hikvision_dvr_monitor_only');
      expect(contract.cameraId, 'channel-11');
      expect(contract.channelId, '11');
      expect(contract.objectLabel, isNull);
      expect(contract.headline, 'HIKVISION_DVR_MONITOR_ONLY VIDEO_LOSS');
    expect(contract.buildSummary(), contains('camera:channel-11'));
    expect(contract.buildSummary(), contains('snapshot:private-fetch'));
    expect(contract.toNormalizedIntelRecord().headline, contract.headline);
  },
  );

  test(
    'hikvision inactive video loss fixture is retained as a cleared recovery event',
    () {
      final normalizer = DvrFixtureContractNormalizer(
        profile: DvrProviderProfile.hikvisionMonitorOnly,
        baseUri: Uri.parse('https://dvr.example.com'),
      );

      final contract = normalizer.normalize(
        payload: {
          'EventNotificationAlert': {
            'UUID': 'DVR-EVT-VIDLOSS-11-CLEAR',
            'eventType': 'videoloss',
            'dateTime': '2026-04-05T18:55:30Z',
            'channelID': '11',
            'eventState': 'inactive',
            'eventDescription': 'videoloss alarm',
          },
        },
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(contract, isNotNull);
      expect(contract!.headline, 'HIKVISION_DVR_MONITOR_ONLY VIDEO_LOSS_CLEARED');
      expect(contract.riskScore, 8);
      expect(contract.buildSummary(), contains('videoloss alarm inactive'));
      expect(contract.toNormalizedIntelRecord().summary, contains('inactive'));
    },
  );

  test('hikvision plate alert normalizes into an LPR truth bucket', () {
    final normalizer = DvrFixtureContractNormalizer(
      profile: DvrProviderProfile.hikvisionMonitorOnly,
      baseUri: Uri.parse('https://dvr.example.com'),
    );

    final contract = normalizer.normalize(
      payload: {
        'EventNotificationAlert': {
          'UUID': 'DVR-EVT-LPR-7',
          'eventType': 'ANPR',
          'dateTime': '2026-03-13T10:26:00Z',
          'channelID': '7',
          'eventState': 'active',
          'ANPR': {'plateNumber': 'CA123456', 'confidence': 96.0},
        },
      },
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(contract, isNotNull);
    expect(contract!.cameraId, 'channel-7');
    expect(contract.objectLabel, 'vehicle');
    expect(contract.plateNumber, 'CA123456');
    expect(contract.headline, 'HIKVISION_DVR_MONITOR_ONLY LPR_ALERT');
    expect(contract.toNormalizedIntelRecord().plateNumber, 'CA123456');
  });

  test('hik-connect camera fault normalizes into video loss', () {
    final normalizer = DvrFixtureContractNormalizer(
      profile: DvrProviderProfile.hikConnectOpenApi,
      baseUri: Uri.parse('https://api.hik-connect.example.com'),
    );

    final contract = normalizer.normalize(
      payload: {
        'guid': 'hik-guid-video-loss-1',
        'msgType': '1',
        'alarmState': '1',
        'alarmSubCategory': 'video_loss',
        'timeInfo': {'startTime': '2026-03-30T00:12:00Z'},
        'eventSource': {
          'sourceID': 'camera-front',
          'sourceName': 'Front Yard',
          'areaName': 'MS Vallee Residence',
          'eventType': 'camera_alarm',
        },
        'alarmRule': {'name': 'Video Loss'},
      },
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(contract, isNotNull);
    expect(contract!.provider, 'hik_connect_openapi');
    expect(contract.cameraId, 'camera-front');
    expect(contract.objectLabel, isNull);
    expect(contract.headline, 'HIK_CONNECT_OPENAPI VIDEO_LOSS');
  });

  test('hik-connect boundary rule normalizes into line crossing', () {
    final normalizer = DvrFixtureContractNormalizer(
      profile: DvrProviderProfile.hikConnectOpenApi,
      baseUri: Uri.parse('https://api.hik-connect.example.com'),
    );

    final contract = normalizer.normalize(
      payload: {
        'guid': 'hik-guid-line-1',
        'msgType': '1',
        'alarmState': '1',
        'alarmSubCategory': 'line_crossing',
        'timeInfo': {'startTime': '2026-03-30T00:14:00Z'},
        'eventSource': {
          'sourceID': 'camera-gate',
          'sourceName': 'Front Gate',
          'areaName': 'MS Vallee Residence',
          'eventType': 'camera_alarm',
        },
        'alarmRule': {'name': 'Line Crossing'},
      },
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(contract, isNotNull);
    expect(contract!.provider, 'hik_connect_openapi');
    expect(contract.cameraId, 'camera-gate');
    expect(contract.objectLabel, 'line_crossing');
    expect(contract.headline, 'HIK_CONNECT_OPENAPI LINE_CROSSING');
  });

  test('hik-connect face match normalizes into FR person truth', () {
    final normalizer = DvrFixtureContractNormalizer(
      profile: DvrProviderProfile.hikConnectOpenApi,
      baseUri: Uri.parse('https://api.hik-connect.example.com'),
    );

    final contract = normalizer.normalize(
      payload: {
        'guid': 'hik-guid-face-1',
        'msgType': '1',
        'alarmState': '1',
        'alarmSubCategory': 'face_match',
        'timeInfo': {'startTime': '2026-03-30T00:16:00Z'},
        'eventSource': {
          'sourceID': 'camera-lobby',
          'sourceName': 'Lobby Camera',
          'areaName': 'Reception',
          'eventType': 'camera_alarm',
        },
        'alarmRule': {'name': 'Face Match'},
        'faceInfo': {
          'faceMatchId': 'RESIDENT-44',
          'faceConfidence': 91.2,
        },
      },
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(contract, isNotNull);
    expect(contract!.provider, 'hik_connect_openapi');
    expect(contract.cameraId, 'camera-lobby');
    expect(contract.zone, 'Reception');
    expect(contract.objectLabel, 'person');
    expect(contract.faceMatchId, 'RESIDENT-44');
    expect(contract.faceConfidence, 91.2);
    expect(contract.headline, 'HIK_CONNECT_OPENAPI FR_MATCH');
    expect(contract.buildSummary(), contains('FR:RESIDENT-44'));
    expect(contract.toNormalizedIntelRecord().objectLabel, 'person');
    expect(contract.toNormalizedIntelRecord().faceMatchId, 'RESIDENT-44');
  });
}
