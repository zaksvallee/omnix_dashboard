import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/hik_connect_alarm_batch.dart';

void main() {
  test('parses Hik-Connect alarm batches into typed messages', () {
    final batch = HikConnectAlarmBatch.fromApiResponse(
      <String, Object?>{
        'errorCode': '0',
        'data': <String, Object?>{
          'batchId': 'batch-001',
          'alarmMsg': <Object?>[
            <String, Object?>{
              'guid': 'hik-connect-guid-1',
              'systemId': 'system-1',
              'msgType': '1',
              'alarmState': '1',
              'alarmSubCategory': 'people_queue_leave',
              'timeInfo': <String, Object?>{
                'startTime': '2026-03-30T10:00:00Z',
              },
              'eventSource': <String, Object?>{
                'sourceID': 'camera-resource-1',
                'sourceName': 'Front Entrance Camera',
                'areaName': 'MS Vallee Residence',
                'eventType': 'camera_alarm',
                'deviceInfo': <String, Object?>{
                  'devName': 'Vallee NVR',
                },
              },
              'alarmRule': <String, Object?>{'name': 'People Queue Leave'},
              'anprInfo': <String, Object?>{'licensePlate': 'CA123456'},
              'fileInfo': <String, Object?>{
                'file': <Object?>[
                  <String, Object?>{
                    'type': '1',
                    'fileUrl': 'https://files.example.com/snapshot.jpg',
                  },
                  <String, Object?>{
                    'type': '2',
                    'fileUrl': 'https://files.example.com/clip.mp4',
                  },
                ],
              },
            },
          ],
        },
      },
    );

    expect(batch.batchId, 'batch-001');
    expect(batch.messages, hasLength(1));
    final message = batch.messages.single;
    expect(message.guid, 'hik-connect-guid-1');
    expect(message.systemId, 'system-1');
    expect(message.msgType, '1');
    expect(message.alarmState, '1');
    expect(message.alarmSubCategory, 'people_queue_leave');
    expect(message.timeInfo.startTime, '2026-03-30T10:00:00Z');
    expect(message.eventSource.sourceId, 'camera-resource-1');
    expect(message.eventSource.sourceName, 'Front Entrance Camera');
    expect(message.eventSource.areaName, 'MS Vallee Residence');
    expect(message.eventSource.deviceName, 'Vallee NVR');
    expect(message.alarmRule.name, 'People Queue Leave');
    expect(message.anprInfo.licensePlate, 'CA123456');
    expect(message.fileInfo.files, hasLength(2));
    expect(message.fileInfo.files.first.fileUrl, contains('snapshot'));
    expect(message.fileInfo.files.last.fileUrl, contains('clip'));
  });

  test('round-trips the typed message back into normalizer payload shape', () {
    final message = HikConnectAlarmMessage.fromJson(
      <String, Object?>{
        'guid': 'hik-connect-guid-2',
        'msgType': '1',
        'alarmState': '1',
        'timeInfo': <String, Object?>{
          'startTime': '2026-03-30T11:00:00Z',
        },
        'eventSource': <String, Object?>{
          'sourceID': 'camera-resource-2',
          'sourceName': 'Back Yard Camera',
          'areaName': 'MS Vallee Residence',
          'deviceInfo': <String, Object?>{'devName': 'Vallee NVR'},
        },
        'fileInfo': <String, Object?>{
          'file': <Object?>[
            <String, Object?>{
              'type': '1',
              'fileUrl': 'https://files.example.com/snapshot-2.jpg',
            },
          ],
        },
      },
    );

    final payload = message.toPayloadMap();

    expect(payload['guid'], 'hik-connect-guid-2');
    expect((payload['timeInfo'] as Map<String, Object?>)['startTime'], '2026-03-30T11:00:00Z');
    expect((payload['eventSource'] as Map<String, Object?>)['sourceID'], 'camera-resource-2');
    expect(
      ((payload['eventSource'] as Map<String, Object?>)['deviceInfo']
              as Map<String, Object?>)['devName'],
      'Vallee NVR',
    );
    expect(
      (((payload['fileInfo'] as Map<String, Object?>)['file'] as List<Object?>)
          .single as Map<String, Object?>)['URL'],
      'https://files.example.com/snapshot-2.jpg',
    );
  });
}
