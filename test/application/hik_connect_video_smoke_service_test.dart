import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_video_smoke_service.dart';

void main() {
  group('HikConnectVideoSmokeService', () {
    test('parses live, playback, and download payloads together', () {
      const service = HikConnectVideoSmokeService();

      final result = service.evaluate(
        liveAddressResponse: <String, Object?>{
          'errorCode': '0',
          'data': <String, Object?>{
            'url': 'wss://stream.example.com/live/token',
            'hlsUrl': 'https://stream.example.com/live/index.m3u8',
          },
        },
        playbackSearchResponse: <String, Object?>{
          'errorCode': '0',
          'data': <String, Object?>{
            'totalCount': 1,
            'pageIndex': 1,
            'pageSize': 50,
            'recordList': <Object?>[
              <String, Object?>{
                'recordId': 'record-001',
                'beginTime': '2026-03-30T00:00:00Z',
                'endTime': '2026-03-30T00:05:00Z',
                'playbackUrl': 'https://stream.example.com/playback/record-001',
              },
            ],
          },
        },
        videoDownloadResponse: <String, Object?>{
          'errorCode': '0',
          'data': <String, Object?>{
            'downloadUrl': 'https://stream.example.com/download/video.mp4',
          },
        },
      );

      expect(result.hasAnyData, isTrue);
      expect(
        result.liveAddress?.primaryUrl,
        'wss://stream.example.com/live/token',
      );
      expect(result.playbackCatalog?.records, hasLength(1));
      expect(
        result.playbackCatalog?.records.single.playbackUrl,
        'https://stream.example.com/playback/record-001',
      );
      expect(
        result.downloadResult?.downloadUrl,
        'https://stream.example.com/download/video.mp4',
      );
    });
  });
}
