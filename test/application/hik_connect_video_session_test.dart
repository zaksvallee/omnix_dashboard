import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/hik_connect_video_session.dart';

void main() {
  test('parses live address responses with multiple protocol urls', () {
    final result = HikConnectLiveAddressResponse.fromApiResponse(
      <String, Object?>{
        'errorCode': '0',
        'data': <String, Object?>{
          'url': 'wss://stream.example.com/live/token',
          'hlsUrl': 'https://stream.example.com/live/index.m3u8',
          'rtspUrl': 'rtsp://stream.example.com/live/token',
          'expireTime': '1743292800000',
        },
      },
    );

    expect(result.primaryUrl, 'wss://stream.example.com/live/token');
    expect(result.urlsByKey['hlsUrl'], 'https://stream.example.com/live/index.m3u8');
    expect(result.urlsByKey['rtspUrl'], 'rtsp://stream.example.com/live/token');
  });

  test('parses playback search result records conservatively', () {
    final result = HikConnectRecordElementSearchResult.fromApiResponse(
      <String, Object?>{
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
    );

    expect(result.totalCount, 1);
    expect(result.records, hasLength(1));
    expect(result.records.single.recordId, 'record-001');
    expect(result.records.single.beginTime, '2026-03-30T00:00:00Z');
    expect(result.records.single.endTime, '2026-03-30T00:05:00Z');
    expect(
      result.records.single.playbackUrl,
      'https://stream.example.com/playback/record-001',
    );
  });

  test('parses video download url responses', () {
    final result = HikConnectVideoDownloadResult.fromApiResponse(
      <String, Object?>{
        'errorCode': '0',
        'data': <String, Object?>{
          'downloadUrl': 'https://stream.example.com/download/video.mp4',
        },
      },
    );

    expect(
      result.downloadUrl,
      'https://stream.example.com/download/video.mp4',
    );
  });
}
