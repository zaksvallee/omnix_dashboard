import 'dart:developer' as developer;

import 'package:supabase/supabase.dart';

import '../llm_provider.dart';
import 'zara_tool.dart';

class FetchFootfallCountTool implements ZaraTool {
  final SupabaseClient supabase;
  final DateTime Function() nowUtc;

  FetchFootfallCountTool({required this.supabase, DateTime Function()? nowUtc})
    : nowUtc = nowUtc ?? _defaultNowUtc;

  @override
  LlmTool get definition => const LlmTool(
    name: 'fetch_footfall_count',
    description:
        'Fetch the peak footfall count for a site in the specified time window. Returns the highest detected occupancy reached during that window.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'time_window': <String, Object?>{
          'type': 'string',
          'enum': <String>['local_site_day'],
          'description':
              'Which time window to count for. local_site_day uses the site reset_hour to define the day boundary.',
        },
      },
      'required': <String>['time_window'],
    },
  );

  @override
  Future<ZaraToolExecutionResult> execute(
    Map<String, Object?> input,
    ZaraToolContext context,
  ) async {
    final timeWindow = (input['time_window'] ?? '').toString().trim();
    if (timeWindow != 'local_site_day') {
      return ZaraToolExecutionResult.error(
        'time_window $timeWindow not supported in v1',
      );
    }

    final siteId = context.siteId?.trim() ?? '';
    if (siteId.isEmpty) {
      return ZaraToolExecutionResult.error(
        'site_id is required for fetch_footfall_count',
      );
    }

    try {
      final siteRows = await supabase
          .from('sites')
          .select('timezone')
          .eq('site_id', siteId)
          .limit(1);
      final siteRow = _firstRowOrNull(siteRows);
      final timezone = _normalizedTimezone(siteRow?['timezone']);

      final configRows = await supabase
          .from('site_occupancy_config')
          .select('reset_hour')
          .eq('site_id', siteId)
          .limit(1);
      final configRow = _firstRowOrNull(configRows);
      final resetHour = _asInt(configRow?['reset_hour']) ?? 3;

      final currentUtc = nowUtc();
      final nowLocal = _siteLocalTime(timezone, currentUtc);
      final sessionDate = _sessionDateString(nowLocal, resetHour: resetHour);

      final sessionRows = await supabase
          .from('site_occupancy_sessions')
          .select('peak_detected,last_detection_at')
          .eq('site_id', siteId)
          .eq('session_date', sessionDate)
          .limit(1);
      final sessionRow = _firstRowOrNull(sessionRows);

      if (sessionRow == null) {
        return ZaraToolExecutionResult(
          output: <String, Object?>{
            'site_id': siteId,
            'time_window': timeWindow,
            'peak_count': 0,
            'session_date': sessionDate,
            'timezone': timezone,
            'reset_hour': resetHour,
            'note': 'no detections recorded',
          },
        );
      }

      return ZaraToolExecutionResult(
        output: <String, Object?>{
          'site_id': siteId,
          'time_window': timeWindow,
          'peak_count': _asInt(sessionRow['peak_detected']) ?? 0,
          'session_date': sessionDate,
          'timezone': timezone,
          'reset_hour': resetHour,
          'last_detection_at': sessionRow['last_detection_at'],
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'fetch_footfall_count failed for ${context.siteId ?? 'unknown-site'}',
        name: 'zara.tools.fetch_footfall_count',
        error: error,
        stackTrace: stackTrace,
      );
      return ZaraToolExecutionResult.error(
        'failed to fetch footfall count: $error',
      );
    }
  }
}

DateTime _defaultNowUtc() => DateTime.now().toUtc();

Map<String, Object?>? _firstRowOrNull(Object? rows) {
  if (rows is! List || rows.isEmpty) {
    return null;
  }
  final first = rows.first;
  if (first is! Map) {
    return null;
  }
  return first.map((key, value) => MapEntry(key.toString(), value));
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '').toString());
}

String _normalizedTimezone(Object? rawTimezone) {
  final normalized = (rawTimezone ?? '').toString().trim();
  if (normalized.isEmpty) {
    return 'Africa/Johannesburg';
  }
  return normalized;
}

DateTime _siteLocalTime(String timezone, DateTime utc) {
  final normalized = timezone.trim();
  if (normalized == 'Africa/Johannesburg') {
    return utc.toUtc().add(const Duration(hours: 2));
  }
  if (normalized.toUpperCase() == 'UTC') {
    return utc.toUtc();
  }
  // TODO(zara): replace this fallback with true site-timezone conversion when
  // multi-timezone sites are provisioned beyond the current SA-first rollout.
  return utc.toUtc().add(const Duration(hours: 2));
}

String _sessionDateString(DateTime observedAtLocal, {required int resetHour}) {
  final normalizedResetHour = resetHour.clamp(0, 23);
  final dayStart = observedAtLocal.isUtc
      ? DateTime.utc(
          observedAtLocal.year,
          observedAtLocal.month,
          observedAtLocal.day,
          normalizedResetHour,
        )
      : DateTime(
          observedAtLocal.year,
          observedAtLocal.month,
          observedAtLocal.day,
          normalizedResetHour,
        );
  final sessionLocalDate = observedAtLocal.isBefore(dayStart)
      ? dayStart.subtract(const Duration(days: 1))
      : dayStart;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${sessionLocalDate.year.toString().padLeft(4, '0')}-${two(sessionLocalDate.month)}-${two(sessionLocalDate.day)}';
}
