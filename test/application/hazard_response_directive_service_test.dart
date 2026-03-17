import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hazard_response_directive_service.dart';

void main() {
  const service = HazardResponseDirectiveService();

  test('builds fire directives with partner and notification wording', () {
    final directives = service.build(
      postureLabel: 'fire and smoke emergency',
      objectLabel: 'smoke',
      siteName: 'MS Vallee Residence',
    );

    expect(directives.signal, 'fire');
    expect(
      directives.dispatchDirective,
      'Stage fire response to MS Vallee Residence and prioritize flame or smoke containment on arrival.',
    );
    expect(
      directives.welfareDirective,
      'Confirm occupant welfare status for MS Vallee Residence as part of the first partner update.',
    );
    expect(
      directives.initiatedDispatchLine,
      'Fire response has been staged while ONYX keeps the client safety and occupant welfare lane active.',
    );
  });

  test('builds leak directives with containment wording', () {
    final directives = service.build(
      postureLabel: 'flood and leak emergency',
      objectLabel: 'water',
      siteName: 'Warehouse 4',
    );

    expect(directives.signal, 'water_leak');
    expect(
      directives.dispatchDirective,
      'Stage leak containment to Warehouse 4 and prioritize water-loss control on arrival.',
    );
    expect(
      directives.initiatedDispatchLine,
      'Leak containment has been staged while ONYX keeps the client safety and occupant welfare lane active.',
    );
  });

  test('builds environment hazard directives with generic site fallback', () {
    final directives = service.build(
      postureLabel: 'environment hazard alert',
      objectLabel: 'equipment',
      siteName: '',
    );

    expect(directives.signal, 'environment_hazard');
    expect(
      directives.dispatchDirective,
      'Stage site safety response to the site and prioritize hazard isolation on arrival.',
    );
    expect(
      directives.welfareDirective,
      'Confirm occupant welfare status for the site as part of the first partner update.',
    );
    expect(
      directives.initiatedDispatchLine,
      'Site safety response has been staged while ONYX keeps the client safety and occupant welfare lane active.',
    );
  });

  test('returns empty directives for non-hazard posture', () {
    final directives = service.build(
      postureLabel: 'monitored movement alert',
      objectLabel: 'vehicle',
      siteName: 'MS Vallee Residence',
    );

    expect(directives.hasHazard, isFalse);
    expect(directives.dispatchDirective, isEmpty);
    expect(directives.welfareDirective, isEmpty);
    expect(directives.initiatedDispatchLine, isEmpty);
  });
}
