import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_yolo_detection_service.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';

void main() {
  group('MonitoringYoloDetectionService', () {
    test(
      'http service fetches digest-auth snapshots and emits semantic intel',
      () async {
        var snapshotGets = 0;
        late Map<String, dynamic> detectorBody;
        final client = MockClient((request) async {
          if (request.url.host == '192.168.0.117') {
            snapshotGets += 1;
            if (snapshotGets == 1) {
              return http.Response(
                '',
                401,
                headers: <String, String>{
                  'www-authenticate':
                      'Digest realm="Hikvision", nonce="nonce123", qop="auth"',
                },
              );
            }
            expect(request.headers['Authorization'], startsWith('Digest '));
            return http.Response.bytes(
              utf8.encode('fake-image'),
              200,
              headers: <String, String>{'content-type': 'image/jpeg'},
            );
          }
          expect(request.url.toString(), 'http://127.0.0.1:8089/detect');
          detectorBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, Object?>{
              'results': <Object?>[
                <String, Object?>{
                  'record_key':
                      'hikvision_dvr|dvr|ext-1|11|2026-04-04T18:22:00.000Z',
                  'primary_label': 'person',
                  'confidence': 0.92,
                  'track_id': 'cam11-person-7',
                  'summary': 'Person visible near the front gate.',
                },
              ],
            }),
            200,
          );
        });
        final service = HttpMonitoringYoloDetectionService(
          client: client,
          endpoint: Uri.parse('http://127.0.0.1:8089/detect'),
        );
        final scope = DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr',
          eventsUri: Uri.parse(
            'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'digest',
          username: 'operator',
          password: 'secret',
          bearerToken: '',
        );

        final records = await service.enrichRecords(
          scope: scope,
          records: <NormalizedIntelRecord>[
            NormalizedIntelRecord(
              provider: 'hikvision_dvr',
              sourceType: 'dvr',
              externalId: 'ext-1',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-JHB',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              cameraId: '11',
              zone: 'Front Gate',
              objectLabel: 'scene_change',
              objectConfidence: 0.58,
              headline: 'Continuous visual watch flagged scene change',
              summary: 'Scene change detected near the front gate.',
              riskScore: 48,
              occurredAtUtc: DateTime.utc(2026, 4, 4, 18, 22),
              snapshotUrl:
                  'http://192.168.0.117/ISAPI/Streaming/channels/1101/picture',
            ),
          ],
        );

        expect(snapshotGets, 2);
        expect(records, hasLength(1));
        expect(records.single.provider, 'hikvision_dvr_yolo');
        expect(
          records.single.externalId,
          'ext-1#yolo:person:track:cam11-person-7',
        );
        expect(records.single.objectLabel, 'person');
        expect(records.single.objectConfidence, 0.92);
        expect(records.single.trackId, 'cam11-person-7');
        expect(
          records.single.headline,
          contains('ONYX observed person activity'),
        );
        expect(
          records.single.summary,
          contains('ONYX observed person activity near Front Gate.'),
        );
        expect(records.single.summary, isNot(contains('Ultralytics')));
        expect(records.single.riskScore, greaterThan(48));

        final items = detectorBody['items'] as List<dynamic>;
        expect(items, hasLength(1));
        final item = items.single as Map<String, dynamic>;
        expect(
          item['record_key'],
          'hikvision_dvr|dvr|ext-1|11|2026-04-04T18:22:00.000Z',
        );
        expect(
          (item['image_url'] as String),
          startsWith('data:image/jpeg;base64,'),
        );
      },
    );

    test(
      'http service skips records that already have semantic labels',
      () async {
        var detectorCalls = 0;
        final client = MockClient((request) async {
          detectorCalls += 1;
          return http.Response('[]', 200);
        });
        final service = HttpMonitoringYoloDetectionService(
          client: client,
          endpoint: Uri.parse('http://127.0.0.1:8089/detect'),
        );
        final scope = DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr',
          eventsUri: Uri.parse(
            'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'none',
          username: '',
          password: '',
          bearerToken: '',
        );

        final records = await service.enrichRecords(
          scope: scope,
          records: <NormalizedIntelRecord>[
            NormalizedIntelRecord(
              provider: 'hikvision_dvr',
              sourceType: 'dvr',
              externalId: 'ext-1',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-JHB',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              cameraId: '11',
              zone: 'Front Gate',
              objectLabel: 'person',
              objectConfidence: 0.87,
              faceMatchId: 'RESIDENT-01',
              headline: 'Front gate person activity',
              summary: 'Existing semantic label already present.',
              riskScore: 61,
              occurredAtUtc: DateTime.utc(2026, 4, 4, 18, 22),
              snapshotUrl:
                  'http://192.168.0.117/ISAPI/Streaming/channels/1101/picture',
            ),
          ],
        );

        expect(records, isEmpty);
        expect(detectorCalls, 0);
      },
    );

    test(
      'http service skips snapshot fetch failures without aborting the whole semantic batch',
      () async {
        var detectorCalls = 0;
        var snapshotFetches = 0;
        final client = MockClient((request) async {
          if (request.url.host == '192.168.0.117') {
            snapshotFetches += 1;
            if (request.url.path.contains('/1101/')) {
              throw http.ClientException('snapshot timeout');
            }
            return http.Response.bytes(
              utf8.encode('good-image'),
              200,
              headers: <String, String>{'content-type': 'image/jpeg'},
            );
          }
          detectorCalls += 1;
          return http.Response(
            jsonEncode(<String, Object?>{
              'results': <Object?>[
                <String, Object?>{
                  'record_key':
                      'hikvision_dvr|dvr|ext-2|12|2026-04-04T18:24:00.000Z',
                  'primary_label': 'vehicle',
                  'confidence': 0.88,
                  'summary': 'Vehicle visible near the driveway.',
                },
              ],
            }),
            200,
          );
        });
        final service = HttpMonitoringYoloDetectionService(
          client: client,
          endpoint: Uri.parse('http://127.0.0.1:8089/detect'),
        );
        final scope = DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr',
          eventsUri: Uri.parse(
            'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'none',
          username: '',
          password: '',
          bearerToken: '',
        );

        final records = await service.enrichRecords(
          scope: scope,
          records: <NormalizedIntelRecord>[
            NormalizedIntelRecord(
              provider: 'hikvision_dvr',
              sourceType: 'dvr',
              externalId: 'ext-1',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-JHB',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              cameraId: '11',
              zone: 'Front Gate',
              objectLabel: 'movement',
              objectConfidence: 0.4,
              headline: 'Probe one',
              summary: 'First probe frame.',
              riskScore: 48,
              occurredAtUtc: DateTime.utc(2026, 4, 4, 18, 22),
              snapshotUrl:
                  'http://192.168.0.117/ISAPI/Streaming/channels/1101/picture',
            ),
            NormalizedIntelRecord(
              provider: 'hikvision_dvr',
              sourceType: 'dvr',
              externalId: 'ext-2',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-JHB',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              cameraId: '12',
              zone: 'Driveway',
              objectLabel: 'movement',
              objectConfidence: 0.4,
              headline: 'Probe two',
              summary: 'Second probe frame.',
              riskScore: 48,
              occurredAtUtc: DateTime.utc(2026, 4, 4, 18, 24),
              snapshotUrl:
                  'http://192.168.0.117/ISAPI/Streaming/channels/1201/picture',
            ),
          ],
        );

        expect(snapshotFetches, 2);
        expect(detectorCalls, 1);
        expect(records, hasLength(1));
        expect(records.single.objectLabel, 'vehicle');
        expect(records.single.externalId, 'ext-2#yolo:vehicle');
      },
    );

    test(
      'http service emits multiple semantic records and face recognition metadata from one frame',
      () async {
        final client = MockClient((request) async {
          if (request.url.host == '192.168.0.117') {
            return http.Response.bytes(
              utf8.encode('semantic-image'),
              200,
              headers: <String, String>{'content-type': 'image/jpeg'},
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'results': <Object?>[
                <String, Object?>{
                  'record_key':
                      'hikvision_dvr|dvr|ext-3|11|2026-04-04T18:25:00.000Z',
                  'primary_label': 'person',
                  'confidence': 0.94,
                  'summary':
                      'Ultralytics detected person activity and also saw a backpack.',
                  'face_match_id': 'RESIDENT-01',
                  'face_confidence': 0.81,
                  'detections': <Object?>[
                    <String, Object?>{'label': 'person', 'confidence': 0.94},
                    <String, Object?>{'label': 'backpack', 'confidence': 0.73},
                  ],
                },
              ],
            }),
            200,
          );
        });
        final service = HttpMonitoringYoloDetectionService(
          client: client,
          endpoint: Uri.parse('http://127.0.0.1:8089/detect'),
        );
        final scope = DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr',
          eventsUri: Uri.parse(
            'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'none',
          username: '',
          password: '',
          bearerToken: '',
        );

        final records = await service.enrichRecords(
          scope: scope,
          records: <NormalizedIntelRecord>[
            NormalizedIntelRecord(
              provider: 'hikvision_dvr',
              sourceType: 'dvr',
              externalId: 'ext-3',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-JHB',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              cameraId: '11',
              zone: 'Front Gate',
              objectLabel: 'movement',
              objectConfidence: 0.61,
              headline: 'Probe frame',
              summary: 'Generic movement probe.',
              riskScore: 44,
              occurredAtUtc: DateTime.utc(2026, 4, 4, 18, 25),
              snapshotUrl:
                  'http://192.168.0.117/ISAPI/Streaming/channels/1101/picture',
            ),
          ],
        );

        expect(records, hasLength(2));
        final personRecord = records.firstWhere(
          (record) => record.objectLabel == 'person',
        );
        final backpackRecord = records.firstWhere(
          (record) => record.objectLabel == 'backpack',
        );
        expect(personRecord.provider, 'hikvision_dvr_yolo');
        expect(personRecord.faceMatchId, 'RESIDENT-01');
        expect(personRecord.faceConfidence, 0.81);
        expect(personRecord.externalId, contains('face:RESIDENT-01'));
        expect(personRecord.summary, contains('ONYX matched RESIDENT-01'));
        expect(backpackRecord.provider, 'hikvision_dvr_yolo');
        expect(backpackRecord.externalId, 'ext-3#yolo:backpack');
        expect(backpackRecord.summary, contains('ONYX observed a backpack'));
      },
    );

    test(
      'http service preserves separate tracked identities for the same semantic label',
      () async {
        final client = MockClient((request) async {
          if (request.url.host == '192.168.0.117') {
            return http.Response.bytes(
              utf8.encode('tracked-image'),
              200,
              headers: <String, String>{'content-type': 'image/jpeg'},
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'results': <Object?>[
                <String, Object?>{
                  'record_key':
                      'hikvision_dvr|dvr|ext-6|11|2026-04-04T18:28:00.000Z',
                  'primary_label': 'person',
                  'confidence': 0.95,
                  'detections': <Object?>[
                    <String, Object?>{
                      'label': 'person',
                      'confidence': 0.95,
                      'track_id': 'cam11-person-1',
                    },
                    <String, Object?>{
                      'label': 'person',
                      'confidence': 0.89,
                      'track_id': 'cam11-person-2',
                    },
                  ],
                  'summary':
                      'Two separate people were visible near the front gate.',
                },
              ],
            }),
            200,
          );
        });
        final service = HttpMonitoringYoloDetectionService(
          client: client,
          endpoint: Uri.parse('http://127.0.0.1:8089/detect'),
        );
        final scope = DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr',
          eventsUri: Uri.parse(
            'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'none',
          username: '',
          password: '',
          bearerToken: '',
        );

        final records = await service.enrichRecords(
          scope: scope,
          records: <NormalizedIntelRecord>[
            NormalizedIntelRecord(
              provider: 'hikvision_dvr',
              sourceType: 'dvr',
              externalId: 'ext-6',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-JHB',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              cameraId: '11',
              zone: 'Front Gate',
              objectLabel: 'movement',
              objectConfidence: 0.64,
              headline: 'Tracked probe frame',
              summary: 'Generic movement probe.',
              riskScore: 46,
              occurredAtUtc: DateTime.utc(2026, 4, 4, 18, 28),
              snapshotUrl:
                  'http://192.168.0.117/ISAPI/Streaming/channels/1101/picture',
            ),
          ],
        );

        expect(records, hasLength(2));
        final trackIds = records.map((record) => record.trackId).toSet();
        expect(
          trackIds,
          containsAll(<String>['cam11-person-1', 'cam11-person-2']),
        );
        expect(
          records.map((record) => record.externalId),
          containsAll(<String>[
            'ext-6#yolo:person:track:cam11-person-1',
            'ext-6#yolo:person:track:cam11-person-2',
          ]),
        );
      },
    );

    test(
      'http service enriches existing vehicle records with license plate matches',
      () async {
        final client = MockClient((request) async {
          if (request.url.host == '192.168.0.117') {
            return http.Response.bytes(
              utf8.encode('vehicle-image'),
              200,
              headers: <String, String>{'content-type': 'image/jpeg'},
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'results': <Object?>[
                <String, Object?>{
                  'record_key':
                      'hikvision_dvr|dvr|ext-4|12|2026-04-04T18:26:00.000Z',
                  'primary_label': 'vehicle',
                  'confidence': 0.91,
                  'plate_number': 'CA 123456',
                  'plate_confidence': 0.87,
                  'summary':
                      'Ultralytics detected vehicle activity. License plate recognition read CA123456.',
                },
              ],
            }),
            200,
          );
        });
        final service = HttpMonitoringYoloDetectionService(
          client: client,
          endpoint: Uri.parse('http://127.0.0.1:8089/detect'),
        );
        final scope = DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr',
          eventsUri: Uri.parse(
            'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'none',
          username: '',
          password: '',
          bearerToken: '',
        );

        final records = await service.enrichRecords(
          scope: scope,
          records: <NormalizedIntelRecord>[
            NormalizedIntelRecord(
              provider: 'hikvision_dvr',
              sourceType: 'dvr',
              externalId: 'ext-4',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-JHB',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              cameraId: '12',
              zone: 'Driveway',
              objectLabel: 'vehicle',
              objectConfidence: 0.66,
              headline: 'Vehicle detected near driveway',
              summary: 'Existing vehicle signal without a plate.',
              riskScore: 52,
              occurredAtUtc: DateTime.utc(2026, 4, 4, 18, 26),
              snapshotUrl:
                  'http://192.168.0.117/ISAPI/Streaming/channels/1201/picture',
            ),
          ],
        );

        expect(records, hasLength(1));
        expect(records.single.objectLabel, 'vehicle');
        expect(records.single.provider, 'hikvision_dvr_yolo');
        expect(records.single.plateNumber, 'CA123456');
        expect(records.single.plateConfidence, 0.87);
        expect(records.single.externalId, contains('plate:CA123456'));
        expect(records.single.summary, contains('ONYX read vehicle CA123456'));
      },
    );

    test(
      'http service keeps lower-confidence semantic detections when they meet the configured full-stack threshold',
      () async {
        final client = MockClient((request) async {
          if (request.url.host == '192.168.0.117') {
            return http.Response.bytes(
              utf8.encode('bag-image'),
              200,
              headers: <String, String>{'content-type': 'image/jpeg'},
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'results': <Object?>[
                <String, Object?>{
                  'record_key':
                      'hikvision_dvr|dvr|ext-5|13|2026-04-04T18:27:00.000Z',
                  'primary_label': 'bag',
                  'confidence': 0.40,
                  'detections': <Object?>[
                    <String, Object?>{'label': 'bag', 'confidence': 0.40},
                  ],
                  'summary':
                      'Ultralytics detected a bag near the side entrance.',
                },
              ],
            }),
            200,
          );
        });
        final service = HttpMonitoringYoloDetectionService(
          client: client,
          endpoint: Uri.parse('http://127.0.0.1:8089/detect'),
        );
        final scope = DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr',
          eventsUri: Uri.parse(
            'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'none',
          username: '',
          password: '',
          bearerToken: '',
        );

        final records = await service.enrichRecords(
          scope: scope,
          records: <NormalizedIntelRecord>[
            NormalizedIntelRecord(
              provider: 'hikvision_dvr',
              sourceType: 'dvr',
              externalId: 'ext-5',
              clientId: 'CLIENT-MS-VALLEE',
              regionId: 'REGION-JHB',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              cameraId: '13',
              zone: 'Side Entrance',
              objectLabel: 'movement',
              objectConfidence: 0.52,
              headline: 'Semantic probe',
              summary: 'Generic movement probe.',
              riskScore: 40,
              occurredAtUtc: DateTime.utc(2026, 4, 4, 18, 27),
              snapshotUrl:
                  'http://192.168.0.117/ISAPI/Streaming/channels/1301/picture',
            ),
          ],
        );

        expect(records, hasLength(1));
        expect(records.single.objectLabel, 'bag');
        expect(records.single.objectConfidence, 0.40);
        expect(records.single.summary, contains('ONYX observed a bag'));
      },
    );
  });
}
