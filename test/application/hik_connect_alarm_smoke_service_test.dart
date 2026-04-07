import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_batch.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_smoke_service.dart';

void main() {
  group('HikConnectAlarmSmokeService', () {
    test('normalizes Hik-Connect alarm messages into ONYX records', () {
      const batch = HikConnectAlarmBatch(
        batchId: 'batch-001',
        messages: <HikConnectAlarmMessage>[
          HikConnectAlarmMessage(
            guid: 'hik-guid-1',
            systemId: '',
            msgType: '1',
            alarmState: '1',
            alarmSubCategory: 'alarmSubCategoryCamera',
            timeInfo: HikConnectAlarmTimeInfo(
              startTime: '2026-03-30T00:10:00Z',
              startTimeLocal: '',
              endTime: '',
              endTimeLocal: '',
            ),
            eventSource: HikConnectAlarmSource(
              sourceId: 'camera-front',
              sourceName: 'Front Yard',
              areaName: 'MS Vallee Residence',
              eventType: '100657',
              deviceName: 'G95721825',
            ),
            alarmRule: HikConnectAlarmRule(name: 'People Queue Leave'),
            anprInfo: HikConnectAnprInfo(licensePlate: 'CA123456'),
            fileInfo: HikConnectAlarmFileInfo(
              files: <HikConnectAlarmFile>[
                HikConnectAlarmFile(
                  type: '1',
                  fileUrl: 'https://files.example.com/snapshot.jpg',
                ),
              ],
            ),
          ),
        ],
      );
      const service = HikConnectAlarmSmokeService();

      final result = service.evaluateBatch(
        batch,
        baseUri: Uri.parse('https://api.hik-connect.example.com'),
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(result.totalMessages, 1);
      expect(result.droppedMessages, 0);
      expect(result.normalizedRecords, hasLength(1));
      expect(result.normalizedRecords.single.externalId, 'hik-guid-1');
      expect(result.normalizedRecords.single.cameraId, 'camera-front');
      expect(result.normalizedRecords.single.zone, 'MS Vallee Residence');
      expect(result.normalizedRecords.single.plateNumber, 'CA123456');
      expect(
        result.normalizedRecords.single.headline,
        'HIK_CONNECT_OPENAPI LPR_ALERT',
      );
      expect(
        result.normalizedRecords.single.summary,
        contains('rule:People Queue Leave'),
      );
      expect(result.normalizedRecords.single.summary, contains('LPR:CA123456'));
    });
  });
}
