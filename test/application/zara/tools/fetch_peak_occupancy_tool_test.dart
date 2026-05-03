import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/zara/tools/fetch_peak_occupancy_tool.dart';
import 'package:omnix_dashboard/application/zara/tools/zara_tool.dart';
import 'package:supabase/supabase.dart';

void main() {
  group('FetchPeakOccupancyTool', () {
    test(
      'happy path returns peak_count for the current local site day',
      () async {
        final tool = FetchPeakOccupancyTool(
          supabase: _buildSupabaseClient(
            _FakePeakOccupancyApi(
              siteRowsById: <String, Map<String, Object?>>{
                'SITE-1': <String, Object?>{'timezone': 'Africa/Johannesburg'},
              },
              configRowsBySiteId: <String, Map<String, Object?>>{
                'SITE-1': <String, Object?>{'reset_hour': 3},
              },
              sessionRowsBySiteAndDate: <String, Map<String, Object?>>{
                'SITE-1|2026-05-01': <String, Object?>{
                  'peak_detected': 47,
                  'last_detection_at': '2026-05-01T08:30:00Z',
                },
              },
            ).handle,
          ),
          nowUtc: () => DateTime.utc(2026, 5, 1, 10, 0),
        );

        final result = await tool.execute(const <String, Object?>{
          'time_window': 'local_site_day',
        }, const ZaraToolContext(siteId: 'SITE-1'));

        expect(result.isError, isFalse);
        expect(result.output['peak_count'], 47);
        expect(result.output['session_date'], '2026-05-01');
        expect(result.output['timezone'], 'Africa/Johannesburg');
        expect(result.output['reset_hour'], 3);
        expect(result.output['last_detection_at'], '2026-05-01T08:30:00Z');
      },
    );

    test('no session row returns zero with a note', () async {
      final tool = FetchPeakOccupancyTool(
        supabase: _buildSupabaseClient(
          _FakePeakOccupancyApi(
            siteRowsById: <String, Map<String, Object?>>{
              'SITE-1': <String, Object?>{'timezone': 'Africa/Johannesburg'},
            },
            configRowsBySiteId: <String, Map<String, Object?>>{
              'SITE-1': <String, Object?>{'reset_hour': 3},
            },
          ).handle,
        ),
        nowUtc: () => DateTime.utc(2026, 5, 1, 10, 0),
      );

      final result = await tool.execute(const <String, Object?>{
        'time_window': 'local_site_day',
      }, const ZaraToolContext(siteId: 'SITE-1'));

      expect(result.isError, isFalse);
      expect(result.output['peak_count'], 0);
      expect(result.output['session_date'], '2026-05-01');
      expect(result.output['note'], 'no detections recorded');
    });

    test('siteId null returns an error result', () async {
      final tool = FetchPeakOccupancyTool(
        supabase: _buildSupabaseClient((request) async {
          return http.Response('[]', 200, request: request);
        }),
      );

      final result = await tool.execute(const <String, Object?>{
        'time_window': 'local_site_day',
      }, const ZaraToolContext());

      expect(result.isError, isTrue);
      expect(result.output['error'], contains('site_id is required'));
    });

    test('unsupported time_window returns an error result', () async {
      final tool = FetchPeakOccupancyTool(
        supabase: _buildSupabaseClient((request) async {
          return http.Response('[]', 200, request: request);
        }),
      );

      final result = await tool.execute(const <String, Object?>{
        'time_window': 'last_24_hours',
      }, const ZaraToolContext(siteId: 'SITE-1'));

      expect(result.isError, isTrue);
      expect(result.output['error'], contains('not supported in v1'));
    });

    test(
      'missing reset_hour defaults to 3 when computing session_date',
      () async {
        final tool = FetchPeakOccupancyTool(
          supabase: _buildSupabaseClient(
            _FakePeakOccupancyApi(
              sessionRowsBySiteAndDate: <String, Map<String, Object?>>{
                'SITE-1|2026-04-30': <String, Object?>{
                  'peak_detected': 9,
                  'last_detection_at': '2026-04-30T23:55:00Z',
                },
              },
            ).handle,
          ),
          nowUtc: () => DateTime.utc(2026, 5, 1, 0, 15),
        );

        final result = await tool.execute(const <String, Object?>{
          'time_window': 'local_site_day',
        }, const ZaraToolContext(siteId: 'SITE-1'));

        expect(result.isError, isFalse);
        expect(result.output['session_date'], '2026-04-30');
        expect(result.output['reset_hour'], 3);
        expect(result.output['peak_count'], 9);
        expect(result.output['timezone'], 'Africa/Johannesburg');
      },
    );
  });
}

SupabaseClient _buildSupabaseClient(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    accessToken: () async => null,
    httpClient: MockClient(handler),
  );
}

class _FakePeakOccupancyApi {
  final Map<String, Map<String, Object?>> siteRowsById;
  final Map<String, Map<String, Object?>> configRowsBySiteId;
  final Map<String, Map<String, Object?>> sessionRowsBySiteAndDate;

  const _FakePeakOccupancyApi({
    this.siteRowsById = const <String, Map<String, Object?>>{},
    this.configRowsBySiteId = const <String, Map<String, Object?>>{},
    this.sessionRowsBySiteAndDate = const <String, Map<String, Object?>>{},
  });

  Future<http.Response> handle(http.Request request) async {
    if (request.method != 'GET') {
      return _jsonResponse(request, 405, <String, Object?>{'error': 'method'});
    }

    if (request.url.path.endsWith('/sites')) {
      final siteId = _eqValue(request.url.queryParameters['site_id']);
      return _rowListResponse(request, siteRowsById[siteId]);
    }

    if (request.url.path.endsWith('/site_occupancy_config')) {
      final siteId = _eqValue(request.url.queryParameters['site_id']);
      return _rowListResponse(request, configRowsBySiteId[siteId]);
    }

    if (request.url.path.endsWith('/site_occupancy_sessions')) {
      final siteId = _eqValue(request.url.queryParameters['site_id']);
      final sessionDate = _eqValue(request.url.queryParameters['session_date']);
      final key = '$siteId|$sessionDate';
      return _rowListResponse(request, sessionRowsBySiteAndDate[key]);
    }

    return _jsonResponse(request, 200, const <Object?>[]);
  }

  http.Response _rowListResponse(
    http.Request request,
    Map<String, Object?>? row,
  ) {
    final rows = row == null ? const <Object?>[] : <Object?>[row];
    return _jsonResponse(request, 200, rows);
  }

  http.Response _jsonResponse(http.Request request, int code, Object body) {
    return http.Response(
      jsonEncode(body),
      code,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }

  String _eqValue(String? queryValue) {
    if (queryValue == null) {
      return '';
    }
    return queryValue.startsWith('eq.') ? queryValue.substring(3) : queryValue;
  }
}
