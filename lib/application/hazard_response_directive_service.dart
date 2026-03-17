class HazardResponseDirectives {
  final String signal;
  final String dispatchDirective;
  final String welfareDirective;
  final String initiatedDispatchLine;
  final String playbookActionType;
  final String playbookDescription;
  final String dispatchActionType;
  final String dispatchPlanDescription;
  final String welfarePlanDescription;
  final String safetyWarningDescription;
  final String responsePolicy;
  final String syntheticRecommendation;

  const HazardResponseDirectives({
    required this.signal,
    required this.dispatchDirective,
    required this.welfareDirective,
    required this.initiatedDispatchLine,
    required this.playbookActionType,
    required this.playbookDescription,
    required this.dispatchActionType,
    required this.dispatchPlanDescription,
    required this.welfarePlanDescription,
    required this.safetyWarningDescription,
    required this.responsePolicy,
    required this.syntheticRecommendation,
  });

  bool get hasHazard => signal.isNotEmpty;
}

class HazardResponseDirectiveService {
  const HazardResponseDirectiveService();

  HazardResponseDirectives build({
    required String postureLabel,
    String objectLabel = '',
    required String siteName,
  }) {
    final signal = _resolveSignal(
      postureLabel: postureLabel,
      objectLabel: objectLabel,
    );
    return buildForSignal(signal: signal, siteName: siteName);
  }

  HazardResponseDirectives buildForSignal({
    required String signal,
    required String siteName,
  }) {
    final normalizedSiteName = siteName.trim().isEmpty ? 'the site' : siteName.trim();
    return switch (signal) {
      'fire' => HazardResponseDirectives(
        signal: signal,
        dispatchDirective:
            'Stage fire response to $normalizedSiteName and prioritize flame or smoke containment on arrival.',
        welfareDirective:
            'Confirm occupant welfare status for $normalizedSiteName as part of the first partner update.',
        initiatedDispatchLine:
            'Fire response has been staged while ONYX keeps the client safety and occupant welfare lane active.',
        playbookActionType: 'ACTIVATE FIRE PLAYBOOK',
        playbookDescription:
            'Lock CCTV fire verification on $normalizedSiteName, pre-stage emergency response, and raise a client safety warning before spread compounds.',
        dispatchActionType: 'DISPATCH FIRE RESPONSE',
        dispatchPlanDescription:
            'Stage fire response for $normalizedSiteName, hold CCTV smoke verification, and keep the client safety call hot while spread risk is still containable.',
        welfarePlanDescription:
            'Trigger immediate occupant welfare verification for $normalizedSiteName while fire response staging is underway.',
        safetyWarningDescription:
            'Prepare a client and operator fire safety warning for $normalizedSiteName with emergency evidence held for human veto.',
        responsePolicy: 'fire_emergency_dispatch',
        syntheticRecommendation:
            'earlier fire brigade staging, occupant welfare checks, and fire spread rehearsal',
      ),
      'water_leak' => HazardResponseDirectives(
        signal: signal,
        dispatchDirective:
            'Stage leak containment to $normalizedSiteName and prioritize water-loss control on arrival.',
        welfareDirective:
            'Confirm occupant welfare status for $normalizedSiteName as part of the first partner update.',
        initiatedDispatchLine:
            'Leak containment has been staged while ONYX keeps the client safety and occupant welfare lane active.',
        playbookActionType: 'ACTIVATE LEAK PLAYBOOK',
        playbookDescription:
            'Lock CCTV leak verification on $normalizedSiteName, pre-stage containment, and raise a client safety warning before water loss compounds.',
        dispatchActionType: 'DISPATCH LEAK RESPONSE',
        dispatchPlanDescription:
            'Stage leak containment for $normalizedSiteName, hold CCTV water-loss verification, and move before pooling damages the site.',
        welfarePlanDescription:
            'Trigger immediate occupant welfare verification for $normalizedSiteName while leak containment staging is underway.',
        safetyWarningDescription:
            'Prepare a client and operator leak safety warning for $normalizedSiteName with containment evidence held for human veto.',
        responsePolicy: 'leak_containment_dispatch',
        syntheticRecommendation:
            'earlier leak containment dispatch, occupant welfare checks, and water-loss rehearsal',
      ),
      'environment_hazard' => HazardResponseDirectives(
        signal: signal,
        dispatchDirective:
            'Stage site safety response to $normalizedSiteName and prioritize hazard isolation on arrival.',
        welfareDirective:
            'Confirm occupant welfare status for $normalizedSiteName as part of the first partner update.',
        initiatedDispatchLine:
            'Site safety response has been staged while ONYX keeps the client safety and occupant welfare lane active.',
        playbookActionType: 'ACTIVATE HAZARD PLAYBOOK',
        playbookDescription:
            'Lock CCTV hazard verification on $normalizedSiteName, pre-stage site safety response, and raise a client warning before conditions worsen.',
        dispatchActionType: 'DISPATCH SAFETY RESPONSE',
        dispatchPlanDescription:
            'Stage site safety response for $normalizedSiteName, hold CCTV hazard verification, and move before conditions worsen for people on site.',
        welfarePlanDescription:
            'Trigger immediate occupant welfare verification for $normalizedSiteName while the safety response is staging.',
        safetyWarningDescription:
            'Prepare a client and operator hazard safety warning for $normalizedSiteName with evidence held for human veto.',
        responsePolicy: 'hazard_safety_dispatch',
        syntheticRecommendation:
            'earlier safety dispatch, occupant welfare checks, and hazard isolation rehearsal',
      ),
      _ => const HazardResponseDirectives(
        signal: '',
        dispatchDirective: '',
        welfareDirective: '',
        initiatedDispatchLine: '',
        playbookActionType: '',
        playbookDescription: '',
        dispatchActionType: '',
        dispatchPlanDescription: '',
        welfarePlanDescription: '',
        safetyWarningDescription: '',
        responsePolicy: '',
        syntheticRecommendation: '',
      ),
    };
  }

  String _resolveSignal({
    required String postureLabel,
    required String objectLabel,
  }) {
    final posture = postureLabel.trim().toLowerCase();
    final object = objectLabel.trim().toLowerCase();
    if (posture.contains('fire') ||
        posture.contains('smoke') ||
        object == 'fire' ||
        object == 'smoke') {
      return 'fire';
    }
    if (posture.contains('flood') ||
        posture.contains('leak') ||
        object == 'water' ||
        object == 'leak') {
      return 'water_leak';
    }
    if (posture.contains('hazard') || object == 'equipment') {
      return 'environment_hazard';
    }
    return '';
  }
}
