import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_watch_outcome_cue_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_policy.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_runtime_store.dart';
import 'package:omnix_dashboard/application/video_fleet_scope_runtime_state_resolver.dart';

void main() {
  group('VideoFleetScopeRuntimeStateResolver', () {
    const resolver = VideoFleetScopeRuntimeStateResolver(
      outcomeCueStore: MonitoringWatchOutcomeCueStore(),
      recoveryStore: MonitoringWatchRecoveryStore(
        policy: MonitoringWatchRecoveryPolicy(),
      ),
    );

    test(
      'resolves cue and recovery labels per scope and drops empty scopes',
      () {
        final output = resolver.resolve(
          scopes: [
            _scope(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              host: '192.168.8.105',
            ),
            _scope(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              host: '192.168.8.106',
            ),
          ],
          outcomeCueStateByScope: {
            'CLIENT-A|SITE-A': MonitoringWatchOutcomeCueState(
              label: 'Resynced',
              recordedAtUtc: DateTime.utc(2026, 3, 14, 10, 3),
            ),
          },
          recoveryStateByScope: {
            'CLIENT-B|SITE-B': MonitoringWatchRecoveryState(
              actor: 'ADMIN',
              outcome: 'Already aligned',
              recordedAtUtc: DateTime.utc(2026, 3, 14, 9, 30),
            ),
          },
          watchRuntimeByScope: {
            'CLIENT-A|SITE-A': MonitoringWatchRuntimeState(
              startedAtUtc: DateTime.utc(2026, 3, 14, 8, 0),
              alertCount: 1,
              repeatCount: 2,
              escalationCount: 1,
              suppressedCount: 3,
              actionHistory: const [
                '10:04 UTC • Camera 2 • Escalation Candidate • Escalated for urgent review because person activity was detected and confidence remained high.',
                '10:02 UTC • Camera 1 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
              ],
              suppressedHistory: const [
                '10:03 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
                '09:58 UTC • Camera 1 • Suppressed because motion remained low-significance.',
              ],
              latestSceneReviewSourceLabel: 'openai:gpt-4.1-mini',
              latestSceneReviewPostureLabel: 'escalation candidate',
              latestSceneDecisionLabel: 'Escalation Candidate',
              latestSceneDecisionSummary:
                  'Escalated for urgent review because person activity was detected and confidence remained high.',
              latestClientDecisionLabel: 'Client Escalated',
              latestClientDecisionSummary:
                  'Client requested urgent control review for the unidentified person.',
              latestClientDecisionAtUtc: DateTime.utc(2026, 3, 14, 10, 6),
              latestSceneReviewSummary:
                  'Person visible near the boundary line.',
              latestSceneReviewUpdatedAtUtc: DateTime.utc(2026, 3, 14, 10, 4),
            ),
          },
          nowUtc: DateTime.utc(2026, 3, 14, 10, 5),
        );

        expect(output.keys, ['CLIENT-A|SITE-A', 'CLIENT-B|SITE-B']);
        expect(output['CLIENT-A|SITE-A']?.operatorOutcomeLabel, 'Resynced');
        expect(output['CLIENT-A|SITE-A']?.lastRecoveryLabel, isNull);
        expect(
          output['CLIENT-A|SITE-A']?.latestSceneReviewLabel,
          'openai:gpt-4.1-mini • escalation candidate • 10:04 UTC',
        );
        expect(
          output['CLIENT-A|SITE-A']?.latestSceneReviewSummary,
          'Person visible near the boundary line.',
        );
        expect(
          output['CLIENT-A|SITE-A']?.latestSceneDecisionLabel,
          'Escalation Candidate',
        );
        expect(
          output['CLIENT-A|SITE-A']?.latestSceneDecisionSummary,
          contains('Escalated for urgent review'),
        );
        expect(
          output['CLIENT-A|SITE-A']?.latestClientDecisionLabel,
          'Client Escalated',
        );
        expect(
          output['CLIENT-A|SITE-A']?.latestClientDecisionSummary,
          'Client requested urgent control review for the unidentified person.',
        );
        expect(output['CLIENT-A|SITE-A']?.alertCount, 1);
        expect(output['CLIENT-A|SITE-A']?.repeatCount, 2);
        expect(output['CLIENT-A|SITE-A']?.escalationCount, 1);
        expect(output['CLIENT-A|SITE-A']?.suppressedCount, 3);
        expect(
          output['CLIENT-A|SITE-A']?.actionHistory,
          [
            '10:04 UTC • Camera 2 • Escalation Candidate • Escalated for urgent review because person activity was detected and confidence remained high.',
            '10:02 UTC • Camera 1 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
          ],
        );
        expect(
          output['CLIENT-A|SITE-A']?.suppressedHistory,
          [
            '10:03 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
            '09:58 UTC • Camera 1 • Suppressed because motion remained low-significance.',
          ],
        );
        expect(
          output['CLIENT-B|SITE-B']?.lastRecoveryLabel,
          'ADMIN • Already aligned • 09:30 UTC',
        );
      },
    );
  });
}

DvrScopeConfig _scope({
  required String clientId,
  required String siteId,
  required String host,
}) {
  return DvrScopeConfig(
    clientId: clientId,
    regionId: 'REGION-GAUTENG',
    siteId: siteId,
    provider: 'hikvision_dvr_monitor_only',
    eventsUri: Uri.parse('http://$host/ISAPI/Event/notification/alertStream'),
    authMode: 'digest',
    username: 'onyx',
    password: 'secret',
    bearerToken: '',
  );
}
