import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_video_payload_loader.dart';

void main() {
  group('HikConnectVideoPayloadLoader', () {
    test('loads a response map from json', () {
      const loader = HikConnectVideoPayloadLoader();

      final response = loader.loadResponseFromJson(
        '''
        {
          "errorCode": "0",
          "data": {
            "url": "wss://stream.example.com/live/token"
          }
        }
        ''',
      );

      expect(response['errorCode'], '0');
      expect(response['data'], isA<Map>());
    });

    test('returns empty map for empty input', () {
      const loader = HikConnectVideoPayloadLoader();
      expect(loader.loadResponseFromJson('   '), isEmpty);
    });
  });
}
