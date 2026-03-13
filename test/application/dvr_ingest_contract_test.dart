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
      profile: DvrProviderProfile.hikvisionIsapi,
      baseUri: Uri.parse('https://dvr.example.com'),
    );

    final contract = normalizer.normalize(
      payload: jsonDecode(fixture),
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(contract, isNotNull);
    expect(contract!.provider, 'hikvision_dvr');
    expect(contract.sourceType, 'dvr');
    expect(contract.externalId, 'DVR-EVT-1001');
    expect(contract.cameraId, 'DVR-001');
    expect(contract.channelId, '3');
    expect(contract.zone, 'loading_bay');
    expect(contract.faceMatchId, 'PERSON-44');
    expect(contract.plateNumber, 'CA123456');
    expect(contract.headline, 'HIKVISION_DVR LINE_CROSSING');
    expect(contract.buildSummary(), contains('channel:3'));
    expect(contract.buildSummary(), contains('FR:PERSON-44 91.2%'));
    expect(contract.buildSummary(), contains('LPR:CA123456 96.4%'));
    expect(contract.evidence.snapshotUrl, contains('/DVR-EVT-1001/snapshot'));
    expect(contract.evidence.clipUrl, contains('/DVR-EVT-1001/clip'));
    expect(contract.toNormalizedIntelRecord().sourceType, 'dvr');
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
}
