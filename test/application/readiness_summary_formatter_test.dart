import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_action_plan.dart';
import 'package:omnix_dashboard/application/readiness_summary_formatter.dart';

void main() {
  group('readiness summary formatter', () {
    test('builds postural echo summary with optional lead sites', () {
      const intents = <MonitoringWatchAutonomyActionPlan>[
        MonitoringWatchAutonomyActionPlan(
          id: 'ECHO-1',
          incidentId: 'SITE-1',
          siteId: 'SITE-1',
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'POSTURAL ECHO',
          description: 'desc',
          countdownSeconds: 0,
          metadata: <String, String>{
            'lead_site': 'SITE-ALPHA',
            'echo_target': 'SITE-BRAVO',
          },
        ),
      ];

      expect(
        buildGlobalReadinessPosturalEchoSummary(intents: intents),
        'Echo 1 • lead SITE-ALPHA • target SITE-BRAVO',
      );
      expect(
        buildGlobalReadinessPosturalEchoSummary(
          intents: intents,
          includeLeadSites: false,
        ),
        'Echo 1 • target SITE-BRAVO',
      );
    });

    test('builds top intent summary with optional site id', () {
      const intents = <MonitoringWatchAutonomyActionPlan>[
        MonitoringWatchAutonomyActionPlan(
          id: 'INTENT-1',
          incidentId: 'SITE-1',
          siteId: 'SITE-1',
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'DISPATCH REINFORCEMENT',
          description: 'Send support team',
          countdownSeconds: 0,
        ),
      ];

      expect(
        buildGlobalReadinessTopIntentSummary(intents: intents),
        'DISPATCH REINFORCEMENT • SITE-1 • Send support team',
      );
      expect(
        buildGlobalReadinessTopIntentSummary(
          intents: intents,
          includeSiteId: false,
        ),
        'DISPATCH REINFORCEMENT • Send support team',
      );
    });
  });
}
