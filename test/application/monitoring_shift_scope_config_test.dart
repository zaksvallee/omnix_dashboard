import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';
import 'package:omnix_dashboard/application/monitoring_shift_scope_config.dart';

void main() {
  group('MonitoringShiftScopeConfig', () {
    test('parses multi-scope JSON entries', () {
      const fallbackSchedule = MonitoringShiftSchedule(
        enabled: true,
        startHour: 6,
        startMinute: 0,
        endHour: 18,
        endMinute: 0,
      );

      final configs = MonitoringShiftScopeConfig.parseJson(
        '''
        [
          {
            "client_id": "CLIENT-MS-VALLEE",
            "region_id": "REGION-GAUTENG",
            "site_id": "SITE-MS-VALLEE-RESIDENCE",
            "start_hour": 6,
            "end_hour": 18
          },
          {
            "client_id": "CLIENT-BETA",
            "site_id": "SITE-BETA",
            "start_hour": 20,
            "start_minute": 30,
            "end_hour": 5,
            "end_minute": 15,
            "enabled": true
          }
        ]
        ''',
        fallbackSchedule: fallbackSchedule,
        fallbackClientId: 'CLIENT-FALLBACK',
        fallbackRegionId: 'REGION-FALLBACK',
        fallbackSiteId: 'SITE-FALLBACK',
      );

      expect(configs, hasLength(2));
      expect(configs.first.clientId, 'CLIENT-MS-VALLEE');
      expect(configs.first.regionId, 'REGION-GAUTENG');
      expect(configs.first.siteId, 'SITE-MS-VALLEE-RESIDENCE');
      expect(configs.first.schedule.startHour, 6);
      expect(configs.first.schedule.endHour, 18);
      expect(configs[1].regionId, 'REGION-FALLBACK');
      expect(configs[1].schedule.startHour, 20);
      expect(configs[1].schedule.startMinute, 30);
      expect(configs[1].schedule.endHour, 5);
      expect(configs[1].schedule.endMinute, 15);
    });

    test('returns empty list for blank config', () {
      const fallbackSchedule = MonitoringShiftSchedule(
        enabled: true,
        startHour: 18,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );

      final configs = MonitoringShiftScopeConfig.parseJson(
        '',
        fallbackSchedule: fallbackSchedule,
        fallbackClientId: 'CLIENT-FALLBACK',
        fallbackRegionId: 'REGION-FALLBACK',
        fallbackSiteId: 'SITE-FALLBACK',
      );

      expect(configs, isEmpty);
    });
  });
}
