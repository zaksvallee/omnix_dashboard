import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/mo_runtime_matching_service.dart';
import 'package:omnix_dashboard/application/monitoring_global_posture_service.dart';
import 'package:omnix_dashboard/application/shadow_mo_validation_summary.dart';

void main() {
  MonitoringGlobalSitePosture buildSite({
    required String siteId,
    required List<OnyxMoShadowMatch> matches,
  }) {
    return MonitoringGlobalSitePosture(
      clientId: 'client-alpha',
      regionId: 'north',
      siteId: siteId,
      heatLevel: MonitoringGlobalHeatLevel.elevated,
      activityScore: 12,
      intelligenceCount: 1,
      escalationCount: 0,
      repeatCount: 0,
      suppressedCount: 0,
      identitySignalCount: 0,
      latestSummary: 'shadow summary',
      lastActivityAtUtc: DateTime.utc(2026, 3, 17, 4),
      moShadowMatchCount: matches.length,
      moShadowSummary: 'shadow summary',
      moShadowMatches: matches,
    );
  }

  OnyxMoShadowMatch buildMatch(String moId, String status) {
    return OnyxMoShadowMatch(
      moId: moId,
      title: moId,
      incidentType: 'intrusion',
      behaviorStage: 'entry',
      validationStatus: status,
      matchScore: 0.8,
    );
  }

  test('builds drift summary from current and baseline validation state', () {
    final summary = buildShadowMoValidationDriftSummary(
      currentSites: [
        buildSite(
          siteId: 'SITE-1',
          matches: [
            buildMatch('MO-1', 'validated'),
            buildMatch('MO-2', 'shadowMode'),
          ],
        ),
      ],
      historySiteSets: [
        [
          buildSite(
            siteId: 'SITE-1',
            matches: [
              buildMatch('MO-3', 'shadowMode'),
              buildMatch('MO-4', 'shadowMode'),
            ],
          ),
        ],
        [
          buildSite(
            siteId: 'SITE-2',
            matches: [buildMatch('MO-5', 'shadowMode')],
          ),
        ],
      ],
    );

    expect(
      summary.summary,
      'Validated 1 • Shadow mode 1 • Drift validated rising',
    );
    expect(summary.headline, 'RISING VALIDATED • 3d');
    expect(
      summary.historySummary,
      'Validated 1 vs 0.0 baseline (+1.0) • Shadow mode 1 vs 1.5 baseline (-0.5)',
    );
  });
}
