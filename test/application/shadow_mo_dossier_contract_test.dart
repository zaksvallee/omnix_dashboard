import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_runtime_matching_service.dart';
import 'package:omnix_dashboard/application/monitoring_global_posture_service.dart';
import 'package:omnix_dashboard/application/shadow_mo_dossier_contract.dart';

void main() {
  test('builds shadow MO site payload with matches', () {
    final site = MonitoringGlobalSitePosture(
      clientId: 'CLIENT-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-OFFICE',
      heatLevel: MonitoringGlobalHeatLevel.elevated,
      activityScore: 88,
      intelligenceCount: 2,
      escalationCount: 1,
      repeatCount: 0,
      suppressedCount: 0,
      identitySignalCount: 0,
      latestSummary: 'Service impersonation concern.',
      lastActivityAtUtc: DateTime.utc(2026, 3, 17, 1, 0),
      dominantSignals: const ['escalation', 'mo_shadow'],
      moShadowMatchCount: 1,
      moShadowSummary:
          'Contractors moved floor to floor in office park (0.89) • office_building, route_anomalies',
      moShadowEventIds: const ['evt-office'],
      moShadowSelectedEventId: 'evt-office',
      moShadowReviewRefs: const ['intel-office'],
      moShadowMatches: const [
        OnyxMoShadowMatch(
          moId: 'MO-EXT-INTEL-NEWS',
          title: 'Contractors moved floor to floor in office park',
          incidentType: 'deception_led_intrusion',
          behaviorStage: 'inside_behavior',
          validationStatus: 'validated',
          runtimeMatchBias: 'PROMOTED_VALIDATED',
          matchScore: 0.89,
          matchedIndicators: ['office_building', 'route_anomalies'],
          recommendedActionPlans: ['RAISE READINESS', 'PREPOSITION RESPONSE'],
        ),
      ],
    );

    final payload = buildShadowMoSitePayload(
      site,
      metadata: const <String, Object?>{'incidentId': 'INC-D-3001'},
    );

    expect(payload['incidentId'], 'INC-D-3001');
    expect(payload['siteId'], 'SITE-OFFICE');
    expect(payload['matchCount'], 1);
    expect(payload['summary'], contains('Contractors moved floor to floor'));
    expect(payload['eventIds'], ['evt-office']);
    expect(payload['selectedEventId'], 'evt-office');
    expect(payload['reviewRefs'], ['intel-office']);
    final matches = payload['matches'] as List<Object?>;
    expect(matches, hasLength(1));
    expect(
      (matches.first as Map<Object?, Object?>)['validationStatus'],
      'validated',
    );
    expect(
      (matches.first as Map<Object?, Object?>)['runtimeMatchBias'],
      'PROMOTED_VALIDATED',
    );
    expect(
      (matches.first as Map<Object?, Object?>)['strengthSummary'],
      'PROMOTED VALIDATED • 0.89',
    );
  });

  test('builds shadow MO dossier payload with configurable count key', () {
    final site = MonitoringGlobalSitePosture(
      clientId: 'CLIENT-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-OFFICE',
      heatLevel: MonitoringGlobalHeatLevel.elevated,
      activityScore: 88,
      intelligenceCount: 2,
      escalationCount: 1,
      repeatCount: 0,
      suppressedCount: 0,
      identitySignalCount: 0,
      latestSummary: 'Service impersonation concern.',
      lastActivityAtUtc: DateTime.utc(2026, 3, 17, 1, 0),
      dominantSignals: const ['escalation', 'mo_shadow'],
      moShadowMatchCount: 1,
      moShadowSummary:
          'Contractors moved floor to floor in office park (0.89) • office_building, route_anomalies',
      moShadowEventIds: const ['evt-office'],
      moShadowSelectedEventId: 'evt-office',
      moShadowReviewRefs: const ['intel-office'],
      moShadowMatches: const [
        OnyxMoShadowMatch(
          moId: 'MO-EXT-INTEL-NEWS',
          title: 'Contractors moved floor to floor in office park',
          incidentType: 'deception_led_intrusion',
          behaviorStage: 'inside_behavior',
          matchScore: 0.89,
          matchedIndicators: ['office_building', 'route_anomalies'],
          recommendedActionPlans: ['RAISE READINESS', 'PREPOSITION RESPONSE'],
        ),
      ],
    );

    final payload = buildShadowMoDossierPayload(
      sites: [site],
      generatedAtUtc: DateTime.utc(2026, 3, 17, 6, 0),
      countKey: 'shadowSiteCount',
      metadata: const <String, Object?>{'reportDate': '2026-03-17'},
    );

    expect(payload['generatedAtUtc'], '2026-03-17T06:00:00.000Z');
    expect(payload['reportDate'], '2026-03-17');
    expect(payload['shadowSiteCount'], 1);
    final sites = payload['sites'] as List<Object?>;
    expect(sites, hasLength(1));
  });

  test('orders shadow dossier sites by reviewed evidence strength', () {
    final newsHeavySite = MonitoringGlobalSitePosture(
      clientId: 'CLIENT-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-NEWS',
      heatLevel: MonitoringGlobalHeatLevel.elevated,
      activityScore: 95,
      intelligenceCount: 3,
      escalationCount: 1,
      repeatCount: 0,
      suppressedCount: 0,
      identitySignalCount: 0,
      latestSummary: 'External shadow pattern seeded.',
      lastActivityAtUtc: DateTime.utc(2026, 3, 17, 3, 0),
      dominantSignals: const ['mo_shadow'],
      moShadowMatchCount: 2,
      moShadowSummary: 'News-led contractor roaming pattern.',
      moShadowEventIds: const ['evt-news-1', 'evt-news-2'],
      moShadowSelectedEventId: 'evt-news-1',
      moShadowMatches: const [
        OnyxMoShadowMatch(
          moId: 'MO-NEWS-1',
          title: 'Contractor roaming precursor',
          incidentType: 'deception_led_intrusion',
          behaviorStage: 'inside_behavior',
          matchScore: 0.91,
          matchedIndicators: ['maintenance_impersonation'],
          recommendedActionPlans: ['REVIEW'],
        ),
      ],
    );
    final reviewedSite = MonitoringGlobalSitePosture(
      clientId: 'CLIENT-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-REVIEWED',
      heatLevel: MonitoringGlobalHeatLevel.elevated,
      activityScore: 72,
      intelligenceCount: 2,
      escalationCount: 1,
      repeatCount: 0,
      suppressedCount: 0,
      identitySignalCount: 0,
      latestSummary: 'Reviewed CCTV shadow evidence.',
      lastActivityAtUtc: DateTime.utc(2026, 3, 17, 2, 0),
      dominantSignals: const ['mo_shadow'],
      moShadowMatchCount: 1,
      moShadowSummary: 'Reviewed contractor roaming at office site.',
      moShadowEventIds: const ['evt-reviewed-2', 'evt-reviewed-1'],
      moShadowSelectedEventId: 'evt-reviewed-1',
      moShadowReviewRefs: const ['intel-reviewed-1'],
      moShadowMatches: const [
        OnyxMoShadowMatch(
          moId: 'MO-REVIEWED-LOW',
          title: 'Access abuse follow-on',
          incidentType: 'deception_led_intrusion',
          behaviorStage: 'entry',
          matchScore: 0.62,
          matchedIndicators: ['credential_misuse'],
          recommendedActionPlans: ['HARDEN ACCESS'],
        ),
        OnyxMoShadowMatch(
          moId: 'MO-REVIEWED-HIGH',
          title: 'Reviewed contractor roaming',
          incidentType: 'deception_led_intrusion',
          behaviorStage: 'inside_behavior',
          matchScore: 0.88,
          matchedIndicators: [
            'maintenance_impersonation',
            'multi_zone_roaming',
          ],
          recommendedActionPlans: ['RAISE READINESS', 'OPEN EVIDENCE'],
        ),
      ],
    );

    final payload = buildShadowMoDossierPayload(
      sites: [newsHeavySite, reviewedSite],
      generatedAtUtc: DateTime.utc(2026, 3, 17, 6, 0),
    );

    final sites = payload['sites'] as List<Object?>;
    expect(sites, hasLength(2));
    final firstSite = sites.first as Map<Object?, Object?>;
    final secondSite = sites.last as Map<Object?, Object?>;
    expect(firstSite['siteId'], 'SITE-REVIEWED');
    expect(secondSite['siteId'], 'SITE-NEWS');
    expect(firstSite['eventIds'], ['evt-reviewed-1', 'evt-reviewed-2']);
    final firstMatches = firstSite['matches'] as List<Object?>;
    expect(
      (firstMatches.first as Map<Object?, Object?>)['moId'],
      'MO-REVIEWED-HIGH',
    );
  });
}
