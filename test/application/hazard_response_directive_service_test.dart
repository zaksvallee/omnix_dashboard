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
    expect(directives.playbookActionType, 'ACTIVATE FIRE PLAYBOOK');
    expect(directives.localActionType, 'FIRE ESCALATION');
    expect(directives.dispatchActionType, 'DISPATCH FIRE RESPONSE');
    expect(directives.responsePolicy, 'fire_emergency_dispatch');
    expect(
      directives.localPlanDescription,
      'Promote immediate fire response, notify the partner lane, and preserve CCTV evidence for emergency escalation.',
    );
    expect(
      directives.playbookDescription,
      'Lock CCTV fire verification on MS Vallee Residence, pre-stage emergency response, and raise a client safety warning before spread compounds.',
    );
    expect(
      directives.dispatchPlanDescription,
      'Stage fire response for MS Vallee Residence, hold CCTV smoke verification, and keep the client safety call hot while spread risk is still containable.',
    );
    expect(
      directives.welfarePlanDescription,
      'Trigger immediate occupant welfare verification for MS Vallee Residence while fire response staging is underway.',
    );
    expect(
      directives.safetyWarningDescription,
      'Prepare a client and operator fire safety warning for MS Vallee Residence with emergency evidence held for human veto.',
    );
    expect(
      directives.operatorDispatchActiveDetails,
      'Dispatching fire response, holding emergency notification, and staging occupant welfare checks.',
    );
    expect(
      directives.operatorDispatchActiveMetadata,
      'Fire emergency dispatch staged • welfare check hot',
    );
    expect(
      directives.operatorClientCallActiveDetails,
      'Client and occupant welfare call in progress while ONYX checks for spread.',
    );
    expect(
      directives.operatorClientCallThinkingMessage,
      'Preparing emergency welfare and client safety call...',
    );
    expect(
      directives.syntheticRecommendation,
      'earlier fire brigade staging, occupant welfare checks, and fire spread rehearsal',
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
    expect(directives.playbookActionType, 'ACTIVATE LEAK PLAYBOOK');
    expect(directives.localActionType, 'LEAK CONTAINMENT');
    expect(directives.dispatchActionType, 'DISPATCH LEAK RESPONSE');
    expect(directives.responsePolicy, 'leak_containment_dispatch');
    expect(
      directives.localPlanDescription,
      'Escalate a likely water-loss incident, protect the site, and lock CCTV evidence before damage spreads.',
    );
    expect(
      directives.operatorDispatchActiveMetadata,
      'Leak containment dispatch staged • welfare check hot',
    );
    expect(
      directives.operatorClientCallThinkingMessage,
      'Preparing leak welfare and client safety call...',
    );
    expect(
      directives.syntheticRecommendation,
      'earlier leak containment dispatch, occupant welfare checks, and water-loss rehearsal',
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
    expect(directives.playbookActionType, 'ACTIVATE HAZARD PLAYBOOK');
    expect(directives.localActionType, 'HAZARD RESPONSE');
    expect(directives.dispatchActionType, 'DISPATCH SAFETY RESPONSE');
    expect(directives.responsePolicy, 'hazard_safety_dispatch');
    expect(
      directives.localPlanDescription,
      'Raise a site hazard response with CCTV evidence attached and keep human veto available.',
    );
    expect(
      directives.operatorDispatchActiveMetadata,
      'Safety dispatch staged • welfare check hot',
    );
    expect(
      directives.operatorClientCallThinkingMessage,
      'Preparing hazard welfare and client safety call...',
    );
    expect(
      directives.syntheticRecommendation,
      'earlier safety dispatch, occupant welfare checks, and hazard isolation rehearsal',
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
    expect(directives.playbookActionType, isEmpty);
    expect(directives.localActionType, isEmpty);
    expect(directives.dispatchActionType, isEmpty);
    expect(directives.syntheticRecommendation, isEmpty);
    expect(directives.operatorDispatchActiveDetails, isEmpty);
    expect(directives.operatorClientCallThinkingMessage, isEmpty);
  });
}
