import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_payload_loader.dart';

void main() {
  group('HikConnectAlarmPayloadLoader', () {
    test('loads a raw mq/messages response', () {
      const loader = HikConnectAlarmPayloadLoader();

      final batch = loader.loadBatchFromJson(
        '''
        {
          "errorCode":"0",
          "data":{
            "batchId":"batch-001",
            "alarmMsg":[
              {
                "guid":"hik-guid-1",
                "msgType":"1",
                "alarmState":"1",
                "timeInfo":{"startTime":"2026-03-30T00:10:00Z"},
                "eventSource":{"sourceID":"camera-front"}
              }
            ]
          }
        }
        ''',
      );

      expect(batch.batchId, 'batch-001');
      expect(batch.messages, hasLength(1));
      expect(batch.messages.single.guid, 'hik-guid-1');
    });

    test('loads a raw message array', () {
      const loader = HikConnectAlarmPayloadLoader();

      final batch = loader.loadBatchFromJson(
        '''
        [
          {
            "guid":"hik-guid-2",
            "msgType":"1",
            "alarmState":"1",
            "timeInfo":{"startTime":"2026-03-30T00:12:00Z"},
            "eventSource":{"sourceID":"camera-back"}
          }
        ]
        ''',
      );

      expect(batch.messages, hasLength(1));
      expect(batch.messages.single.guid, 'hik-guid-2');
    });
  });
}
