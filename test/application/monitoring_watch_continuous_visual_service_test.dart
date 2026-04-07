import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_watch_continuous_visual_service.dart';

void main() {
  DvrScopeConfig buildScope({Map<String, String> cameraLabels = const {}}) {
    return DvrScopeConfig(
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      provider: 'hikvision_dvr_monitor_only',
      eventsUri: Uri.parse(
        'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
      ),
      authMode: 'none',
      username: '',
      password: '',
      bearerToken: '',
      cameraLabels: cameraLabels,
    );
  }

  Uint8List solidJpeg(int value) {
    final image = img.Image(width: 96, height: 96);
    img.fill(image, color: img.ColorRgb8(value, value, value));
    return Uint8List.fromList(img.encodeJpg(image, quality: 80));
  }

  test(
    'learns a baseline and emits a sustained scene-change candidate',
    () async {
      final channelOneUri = Uri.parse(
        'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
      );
      var channelOneFetchCount = 0;
      final client = MockClient((request) async {
        if (request.url == channelOneUri) {
          channelOneFetchCount += 1;
          final bytes = channelOneFetchCount <= 3
              ? solidJpeg(8)
              : solidJpeg(248);
          return http.Response.bytes(
            bytes,
            200,
            headers: const {'content-type': 'image/jpeg'},
          );
        }
        return http.Response('', 404);
      });
      final service = MonitoringWatchContinuousVisualService(client: client);
      final scope = buildScope();

      final first = await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 0),
      );
      final second = await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 12),
      );
      final third = await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 24),
      );
      final fourth = await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 36),
      );
      final fifth = await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 48),
      );

      expect(first, isNotNull);
      expect(
        first!.snapshot.status,
        MonitoringWatchContinuousVisualStatus.learning,
      );
      expect(first.candidates, isEmpty);
      expect(second, isNotNull);
      expect(second!.candidates, isEmpty);
      expect(third, isNotNull);
      expect(third!.snapshot.baselineReadyCameraCount, 1);
      expect(third.candidates, isEmpty);
      expect(fourth, isNotNull);
      expect(
        fourth!.snapshot.status,
        MonitoringWatchContinuousVisualStatus.active,
      );
      expect(fourth.candidates, isEmpty);
      expect(fourth.snapshot.hotCameraId, 'channel-1');
      expect(fourth.snapshot.hotCameraLabel, 'Camera 1');
      expect(fourth.snapshot.hotCameraChangeStreakCount, 1);
      expect(
        fourth.snapshot.hotCameraChangeStage,
        MonitoringWatchContinuousVisualChangeStage.watching,
      );
      expect(
        fourth.snapshot.summary,
        contains('tracking a fresh scene change on Camera 1'),
      );
      expect(fifth, isNotNull);
      expect(
        fifth!.snapshot.status,
        MonitoringWatchContinuousVisualStatus.alerting,
      );
      expect(fifth.snapshot.reachableCameraCount, 1);
      expect(fifth.snapshot.baselineReadyCameraCount, 1);
      expect(fifth.snapshot.hotCameraId, 'channel-1');
      expect(fifth.snapshot.hotCameraChangeStreakCount, 2);
      expect(
        fifth.snapshot.hotCameraChangeStage,
        MonitoringWatchContinuousVisualChangeStage.sustained,
      );
      expect(fifth.candidates, hasLength(1));
      expect(fifth.candidates.single.cameraId, 'channel-1');
      expect(fifth.candidates.single.snapshotUri, channelOneUri);
      expect(fifth.candidates.single.sceneDeltaScore, greaterThan(0.5));
      expect(
        fifth.candidates.single.record.headline,
        contains('Continuous visual watch flagged sustained scene change'),
      );
      expect(
        service
            .snapshotForScope('CLIENT-MS-VALLEE', 'SITE-MS-VALLEE-RESIDENCE')
            ?.summary,
        contains('sustained scene change on Camera 1'),
      );
    },
  );

  test(
    'promotes sustained change into persistent deviation after dwell',
    () async {
      final channelOneUri = Uri.parse(
        'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
      );
      var channelOneFetchCount = 0;
      final client = MockClient((request) async {
        if (request.url == channelOneUri) {
          channelOneFetchCount += 1;
          final bytes = channelOneFetchCount <= 3
              ? solidJpeg(8)
              : solidJpeg(248);
          return http.Response.bytes(
            bytes,
            200,
            headers: const {'content-type': 'image/jpeg'},
          );
        }
        return http.Response('', 404);
      });
      final service = MonitoringWatchContinuousVisualService(
        client: client,
        candidateCooldown: const Duration(seconds: 10),
        persistentChangeSweepThreshold: 3,
      );
      final scope = buildScope();

      await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 0),
      );
      await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 12),
      );
      await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 24),
      );
      await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 36),
      );
      final sustained = await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 48),
      );
      final persistent = await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 1, 0),
      );
      final persistentFollowUp = await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 1, 12),
      );

      expect(sustained, isNotNull);
      expect(sustained!.candidates, hasLength(1));
      expect(persistent, isNotNull);
      expect(
        persistent!.snapshot.hotCameraChangeStage,
        MonitoringWatchContinuousVisualChangeStage.persistent,
      );
      expect(
        persistent.snapshot.hotCameraChangeActiveSinceUtc,
        DateTime.utc(2026, 4, 4, 8, 0, 36),
      );
      expect(persistent.candidates, hasLength(1));
      expect(persistentFollowUp, isNotNull);
      expect(persistentFollowUp!.candidates, isEmpty);
      expect(
        persistent.candidates.single.record.headline,
        contains('persistent scene deviation'),
      );
      expect(
        persistent.snapshot.summary,
        contains('persistent scene deviation on Camera 1'),
      );
    },
  );

  test('suppresses repeat candidates inside the cooldown window', () async {
    final channelOneUri = Uri.parse(
      'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
    );
    final sequence = <Uint8List>[
      solidJpeg(8),
      solidJpeg(8),
      solidJpeg(8),
      solidJpeg(248),
      solidJpeg(248),
      solidJpeg(248),
      solidJpeg(8),
    ];
    var channelOneFetchCount = 0;
    final client = MockClient((request) async {
      if (request.url == channelOneUri) {
        final index = channelOneFetchCount.clamp(0, sequence.length - 1);
        channelOneFetchCount += 1;
        return http.Response.bytes(
          sequence[index],
          200,
          headers: const {'content-type': 'image/jpeg'},
        );
      }
      return http.Response('', 404);
    });
    final service = MonitoringWatchContinuousVisualService(client: client);
    final scope = buildScope();

    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 0),
    );
    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 12),
    );
    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 24),
    );
    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 36),
    );
    final firstCandidate = await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 48),
    );
    final suppressed = await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 1, 0),
    );
    final secondCandidate = await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 3, 0),
    );

    expect(firstCandidate, isNotNull);
    expect(firstCandidate!.candidates, hasLength(1));
    expect(suppressed, isNotNull);
    expect(suppressed!.candidates, isEmpty);
    expect(secondCandidate, isNotNull);
    expect(secondCandidate!.candidates, hasLength(1));
  });

  test('named gate cameras produce area-aware priority summaries', () async {
    final channelOneUri = Uri.parse(
      'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
    );
    var channelOneFetchCount = 0;
    final client = MockClient((request) async {
      if (request.url == channelOneUri) {
        channelOneFetchCount += 1;
        final bytes = channelOneFetchCount <= 3 ? solidJpeg(8) : solidJpeg(248);
        return http.Response.bytes(
          bytes,
          200,
          headers: const {'content-type': 'image/jpeg'},
        );
      }
      return http.Response('', 404);
    });
    final service = MonitoringWatchContinuousVisualService(client: client);
    final scope = buildScope(
      cameraLabels: const <String, String>{'1': 'Front Gate Perimeter'},
    );

    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 0),
    );
    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 12),
    );
    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 24),
    );
    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 36),
    );
    final candidate = await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 48),
    );

    expect(candidate, isNotNull);
    expect(candidate!.snapshot.hotAreaLabel, 'Front Gate');
    expect(candidate.snapshot.hotWatchRuleKey, 'perimeter_watch');
    expect(candidate.snapshot.hotWatchPriorityLabel, 'High');
    expect(candidate.snapshot.hotZoneLabel, 'Perimeter');
    expect(candidate.snapshot.watchPostureKey, 'perimeter_pressure');
    expect(candidate.snapshot.watchPostureLabel, 'Perimeter pressure');
    expect(candidate.snapshot.watchAttentionLabel, 'elevated');
    expect(candidate.snapshot.watchSourceLabel, 'single_camera');
    expect(candidate.candidates, hasLength(1));
    expect(
      candidate.candidates.single.record.headline,
      contains('perimeter sustained scene change near Front Gate'),
    );
    expect(
      candidate.candidates.single.record.riskScore,
      greaterThanOrEqualTo(60),
    );
  });

  test(
    'cross-camera front-gate deviations correlate into one area signal',
    () async {
      final channelOneUri = Uri.parse(
        'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
      );
      final channelTwoUri = Uri.parse(
        'http://127.0.0.1:11635/ISAPI/Streaming/channels/201/picture',
      );
      final fetchCounts = <Uri, int>{};
      final client = MockClient((request) async {
        if (request.url == channelOneUri || request.url == channelTwoUri) {
          final count = (fetchCounts[request.url] ?? 0) + 1;
          fetchCounts[request.url] = count;
          final bytes = count <= 3 ? solidJpeg(8) : solidJpeg(248);
          return http.Response.bytes(
            bytes,
            200,
            headers: const {'content-type': 'image/jpeg'},
          );
        }
        return http.Response('', 404);
      });
      final service = MonitoringWatchContinuousVisualService(client: client);
      final scope = buildScope(
        cameraLabels: const <String, String>{
          '1': 'Front Gate Perimeter',
          '2': 'Front Gate Entry',
        },
      );

      await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 0),
      );
      await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 12),
      );
      await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 24),
      );
      await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 36),
      );
      final candidate = await service.sweepScope(
        scope: scope,
        nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 48),
      );

      expect(candidate, isNotNull);
      expect(candidate!.snapshot.correlatedContextLabel, 'Front Gate');
      expect(candidate.snapshot.correlatedAreaLabel, 'Front Gate');
      expect(candidate.snapshot.correlatedZoneLabel, 'Perimeter');
      expect(candidate.snapshot.correlatedWatchRuleKey, 'perimeter_watch');
      expect(candidate.snapshot.correlatedWatchPriorityLabel, 'High');
      expect(
        candidate.snapshot.correlatedChangeStage,
        MonitoringWatchContinuousVisualChangeStage.sustained,
      );
      expect(candidate.snapshot.watchPostureKey, 'perimeter_pressure');
      expect(candidate.snapshot.watchPostureLabel, 'Perimeter pressure');
      expect(candidate.snapshot.watchAttentionLabel, 'high');
      expect(candidate.snapshot.watchSourceLabel, 'cross_camera');
      expect(candidate.snapshot.correlatedCameraCount, 2);
      expect(
        candidate.snapshot.correlatedCameraLabels,
        containsAll(<String>['Front Gate Entry', 'Front Gate Perimeter']),
      );
      expect(
        candidate.snapshot.summary,
        contains(
          'sustained high-priority perimeter pressure near Front Gate across 2 cameras',
        ),
      );
    },
  );

  test('transient snapshot errors preserve the active change streak', () async {
    final channelOneUri = Uri.parse(
      'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
    );
    var channelOneFetchCount = 0;
    final client = MockClient((request) async {
      if (request.url == channelOneUri) {
        channelOneFetchCount += 1;
        if (channelOneFetchCount == 5) {
          return http.Response('', 503);
        }
        final bytes = channelOneFetchCount <= 3 ? solidJpeg(8) : solidJpeg(248);
        return http.Response.bytes(
          bytes,
          200,
          headers: const {'content-type': 'image/jpeg'},
        );
      }
      return http.Response('', 404);
    });
    final service = MonitoringWatchContinuousVisualService(client: client);
    final scope = buildScope();

    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 0),
    );
    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 12),
    );
    await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 24),
    );
    final firstChange = await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 36),
    );
    final transientFailure = await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 0, 48),
    );
    final recovered = await service.sweepScope(
      scope: scope,
      nowUtc: DateTime.utc(2026, 4, 4, 8, 1, 0),
    );

    expect(firstChange, isNotNull);
    expect(firstChange!.snapshot.hotCameraChangeStreakCount, 1);
    expect(transientFailure, isNotNull);
    expect(transientFailure!.snapshot.hotCameraChangeStreakCount, 1);
    expect(recovered, isNotNull);
    expect(recovered!.snapshot.hotCameraChangeStreakCount, 2);
    expect(recovered.candidates, hasLength(1));
  });
}
