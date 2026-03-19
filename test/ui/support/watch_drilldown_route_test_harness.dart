import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';
import 'package:omnix_dashboard/application/monitoring_shift_scope_config.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';

Future<void> seedValleeLimitedWatchRuntime({
  required DispatchPersistenceService persistence,
  int alertCount = 0,
}) async {
  await persistence.saveMonitoringWatchRuntimeState({
    'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE': <String, Object?>{
      'started_at_utc': DateTime.utc(
        2026,
        3,
        18,
        12,
        0,
      ).toIso8601String(),
      'monitoring_available': false,
      'monitoring_availability_detail': 'One remote camera feed is stale.',
      'alert_count': alertCount,
    },
  });
}

Future<void> pumpValleeWatchDrilldownRouteApp(
  WidgetTester tester, {
  required OnyxRoute route,
  Key? key,
}) async {
  await tester.pumpWidget(
    OnyxApp(
      key: key,
      supabaseReady: false,
      initialRouteOverride: route,
      monitoringShiftScopeConfigsOverride: const [
        MonitoringShiftScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          schedule: MonitoringShiftSchedule(
            enabled: true,
            startHour: 18,
            startMinute: 0,
            endHour: 6,
            endMinute: 0,
          ),
        ),
      ],
      dvrScopeConfigsOverride: [
        DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'monitor_only_dvr',
          eventsUri: Uri.parse('https://edge.example.com/events'),
          authMode: 'bearer',
          username: '',
          password: '',
          bearerToken: 'token',
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}
