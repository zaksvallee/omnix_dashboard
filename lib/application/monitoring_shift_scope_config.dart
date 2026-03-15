import 'dart:convert';

import 'monitoring_shift_schedule_service.dart';

class MonitoringShiftScopeConfig {
  final String clientId;
  final String regionId;
  final String siteId;
  final MonitoringShiftSchedule schedule;

  const MonitoringShiftScopeConfig({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.schedule,
  });

  String get scopeKey => '${clientId.trim()}|${siteId.trim()}';

  static List<MonitoringShiftScopeConfig> parseJson(
    String rawJson, {
    required MonitoringShiftSchedule fallbackSchedule,
    required String fallbackClientId,
    required String fallbackRegionId,
    required String fallbackSiteId,
  }) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(trimmed);
    final rawItems = switch (decoded) {
      List value => value,
      Map value => value['items'] is List ? value['items'] as List : const [],
      _ => const [],
    };
    final configs = <MonitoringShiftScopeConfig>[];
    for (final item in rawItems.whereType<Map>()) {
      String readString(String key, {String fallback = ''}) {
        final value = (item[key] ?? fallback).toString().trim();
        return value;
      }

      int readInt(String key, int fallback) {
        final value = item[key];
        return switch (value) {
          int entry => entry,
          num entry => entry.toInt(),
          String entry => int.tryParse(entry.trim()) ?? fallback,
          _ => fallback,
        };
      }

      final clientId = readString('client_id', fallback: fallbackClientId);
      final regionId = readString('region_id', fallback: fallbackRegionId);
      final siteId = readString('site_id', fallback: fallbackSiteId);
      if (clientId.isEmpty || siteId.isEmpty) {
        continue;
      }
      final enabledValue = item['enabled'];
      final enabled = switch (enabledValue) {
        bool entry => entry,
        String entry =>
          entry.trim().toLowerCase() != 'false' &&
              entry.trim().toLowerCase() != '0',
        _ => fallbackSchedule.enabled,
      };
      configs.add(
        MonitoringShiftScopeConfig(
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          schedule: MonitoringShiftSchedule(
            enabled: enabled,
            startHour: readInt('start_hour', fallbackSchedule.startHour),
            startMinute: readInt('start_minute', fallbackSchedule.startMinute),
            endHour: readInt('end_hour', fallbackSchedule.endHour),
            endMinute: readInt('end_minute', fallbackSchedule.endMinute),
          ),
        ),
      );
    }
    return configs;
  }
}
