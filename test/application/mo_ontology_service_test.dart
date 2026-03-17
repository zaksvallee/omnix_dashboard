import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_ontology_service.dart';

void main() {
  const service = MoOntologyService();

  test('canonicalizes contractor impersonation into ONYX MO vocabulary', () {
    final profile = service.profile(
      title: 'Contractors entered a business park office after hours',
      summary:
          'Suspects posed as maintenance contractors, returned later after hours, moved floor to floor, and tried several restricted office doors before stealing devices.',
    );

    expect(profile.environmentTypes, contains('office_building'));
    expect(profile.preIncidentIndicators, contains('repeat_visitation'));
    expect(profile.entryIndicators, contains('spoofed_service_access'));
    expect(
      profile.insideBehaviorIndicators,
      containsAll(<String>['multi_zone_roaming', 'room_probing']),
    );
    expect(
      profile.deceptionIndicators,
      contains('maintenance_impersonation'),
    );
    expect(profile.observableCues, contains('after_hours_presence'));
    expect(profile.attackGoal, 'theft');
    expect(
      profile.recommendedActionPlans,
      containsAll(<String>['PROMOTE SCENE REVIEW', 'RAISE READINESS']),
    );
    expect(profile.patternConfidence, 'high');
    expect(profile.riskWeight, greaterThanOrEqualTo(60));
  });
}
