import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/dvr_http_auth.dart';
import 'package:omnix_dashboard/application/monitoring_watch_vision_review_service.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringWatchVisionReviewService', () {
    test('openai review fetches digest-auth snapshot and parses json output', () async {
      var snapshotGets = 0;
      late Map<String, dynamic> aiBody;
      final client = MockClient((request) async {
        if (request.url.host == '192.168.8.105') {
          snapshotGets += 1;
          if (snapshotGets == 1) {
            return http.Response(
              '',
              401,
              headers: {
                'www-authenticate':
                    'Digest realm="Hikvision", nonce="nonce123", qop="auth"',
              },
            );
          }
          expect(request.headers['Authorization'], startsWith('Digest '));
          return http.Response.bytes(
            utf8.encode('fake-image'),
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }
        expect(request.url.toString(), 'https://api.openai.com/v1/responses');
        aiBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'output_text': jsonEncode({
              'primary_object': 'person',
              'confidence': 'high',
              'posture': 'boundary',
              'risk_delta': 12,
              'tags': ['person', 'line_crossing'],
              'summary': 'Person visible near the boundary line.',
            }),
          }),
          200,
        );
      });
      final service = OpenAiMonitoringWatchVisionReviewService(
        client: client,
        apiKey: 'test-key',
        model: 'gpt-4.1-mini',
      );

      final review = await service.review(
        event: _intel(
          objectLabel: 'movement',
          objectConfidence: 0.41,
          riskScore: 72,
          headline: 'HIKVISION_DVR_MONITOR_ONLY LINE_CROSSING',
          summary: 'Boundary motion event',
          snapshotUrl:
              'http://192.168.8.105/ISAPI/Streaming/channels/101/picture',
        ),
        authConfig: const DvrHttpAuthConfig(
          mode: DvrHttpAuthMode.digest,
          username: 'operator',
          password: 'secret',
        ),
        priorReviewedEvents: 1,
        groupedEventCount: 2,
      );

      expect(snapshotGets, 2);
      expect(review.usedFallback, isFalse);
      expect(review.sourceLabel, 'openai:gpt-4.1-mini');
      expect(review.primaryObjectLabel, 'person');
      expect(review.indicatesBoundaryConcern, isTrue);
      expect(review.riskDelta, 12);

      final input = aiBody['input'] as List<dynamic>;
      final user = input.last as Map<String, dynamic>;
      final content = user['content'] as List<dynamic>;
      final image = content.last as Map<String, dynamic>;
      expect(image['type'], 'input_image');
      expect((image['image_url'] as String), startsWith('data:image/jpeg;base64,'));
    });

    test('falls back to metadata review when snapshot fetch fails', () async {
      final client = MockClient((request) async {
        if (request.url.host == '192.168.8.105') {
          return http.Response('', 500);
        }
        fail('AI endpoint should not be called when snapshot fetch fails.');
      });
      final service = OpenAiMonitoringWatchVisionReviewService(
        client: client,
        apiKey: 'test-key',
        model: 'gpt-4.1-mini',
      );

      final review = await service.review(
        event: _intel(
          objectLabel: 'vehicle',
          objectConfidence: 0.82,
          riskScore: 70,
          headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
          summary: 'Vehicle motion event',
          snapshotUrl:
              'http://192.168.8.105/ISAPI/Streaming/channels/101/picture',
        ),
        authConfig: const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
      );

      expect(review.usedFallback, isTrue);
      expect(review.sourceLabel, 'metadata-only');
      expect(review.primaryObjectLabel, 'vehicle');
    });
  });
}

IntelligenceReceived _intel({
  required String objectLabel,
  required double objectConfidence,
  required int riskScore,
  required String headline,
  required String summary,
  required String? snapshotUrl,
}) {
  return IntelligenceReceived(
    eventId: 'evt-1',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 14, 21, 14),
    intelligenceId: 'intel-1',
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-1',
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    cameraId: 'channel-1',
    objectLabel: objectLabel,
    objectConfidence: objectConfidence,
    headline: headline,
    summary: summary,
    riskScore: riskScore,
    snapshotUrl: snapshotUrl,
    canonicalHash: 'hash-1',
  );
}
