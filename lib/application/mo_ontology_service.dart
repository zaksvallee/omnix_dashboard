class OnyxMoOntologyProfile {
  final List<String> environmentTypes;
  final String incidentType;
  final String behaviorStage;
  final List<String> preIncidentIndicators;
  final List<String> entryIndicators;
  final List<String> insideBehaviorIndicators;
  final List<String> coordinationIndicators;
  final List<String> extractionIndicators;
  final List<String> deceptionIndicators;
  final List<String> systemPressureIndicators;
  final List<String> observableCues;
  final List<String> falsePositiveConflicts;
  final List<String> recommendedActionPlans;
  final String attackGoal;
  final String patternConfidence;
  final String evidenceQuality;
  final int riskWeight;
  final double observabilityScore;
  final double localRelevanceScore;
  final Map<String, int> siteTypeOverrides;

  const OnyxMoOntologyProfile({
    this.environmentTypes = const <String>[],
    this.incidentType = 'unknown',
    this.behaviorStage = 'unknown',
    this.preIncidentIndicators = const <String>[],
    this.entryIndicators = const <String>[],
    this.insideBehaviorIndicators = const <String>[],
    this.coordinationIndicators = const <String>[],
    this.extractionIndicators = const <String>[],
    this.deceptionIndicators = const <String>[],
    this.systemPressureIndicators = const <String>[],
    this.observableCues = const <String>[],
    this.falsePositiveConflicts = const <String>[],
    this.recommendedActionPlans = const <String>[],
    this.attackGoal = 'unknown',
    this.patternConfidence = 'low',
    this.evidenceQuality = 'medium',
    this.riskWeight = 0,
    this.observabilityScore = 0,
    this.localRelevanceScore = 0,
    this.siteTypeOverrides = const <String, int>{},
  });
}

class MoOntologyService {
  const MoOntologyService();

  OnyxMoOntologyProfile profile({
    required String title,
    required String summary,
    String environmentHint = '',
  }) {
    final text = '$title $summary ${environmentHint.trim()}'.toLowerCase();
    final environmentTypes = _environmentTypes(text);
    final preIncidentIndicators = _preIncidentIndicators(text);
    final entryIndicators = _entryIndicators(text);
    final insideBehaviorIndicators = _insideBehaviorIndicators(text);
    final coordinationIndicators = _coordinationIndicators(text);
    final extractionIndicators = _extractionIndicators(text);
    final deceptionIndicators = _deceptionIndicators(text);
    final systemPressureIndicators = _systemPressureIndicators(text);
    final observableCues = _observableCues(text);
    final attackGoal = _attackGoal(text);
    final behaviorStage = _behaviorStage(
      preIncidentIndicators: preIncidentIndicators,
      entryIndicators: entryIndicators,
      insideBehaviorIndicators: insideBehaviorIndicators,
      extractionIndicators: extractionIndicators,
    );
    final incidentType = _incidentType(
      attackGoal: attackGoal,
      entryIndicators: entryIndicators,
      deceptionIndicators: deceptionIndicators,
      systemPressureIndicators: systemPressureIndicators,
    );
    final falsePositiveConflicts = _falsePositiveConflicts(
      environmentTypes: environmentTypes,
      preIncidentIndicators: preIncidentIndicators,
      deceptionIndicators: deceptionIndicators,
    );
    final recommendedActionPlans = _recommendedActionPlans(
      preIncidentIndicators: preIncidentIndicators,
      entryIndicators: entryIndicators,
      insideBehaviorIndicators: insideBehaviorIndicators,
      coordinationIndicators: coordinationIndicators,
      deceptionIndicators: deceptionIndicators,
      systemPressureIndicators: systemPressureIndicators,
    );
    final observabilityScore = _bounded(
      observableCues.length / 6,
    );
    final localRelevanceScore = _bounded(
      0.35 +
          (environmentTypes.isEmpty ? 0 : 0.25) +
          (recommendedActionPlans.isEmpty ? 0 : 0.2) +
          (falsePositiveConflicts.isEmpty ? 0.15 : 0.05),
    );
    final matchedGroups = <int>[
      preIncidentIndicators.length,
      entryIndicators.length,
      insideBehaviorIndicators.length,
      coordinationIndicators.length,
      extractionIndicators.length,
      deceptionIndicators.length,
      systemPressureIndicators.length,
    ].where((count) => count > 0).length;
    final patternConfidence = matchedGroups >= 4
        ? 'high'
        : matchedGroups >= 2
        ? 'medium'
        : 'low';
    final riskWeight = _riskWeight(
      environmentTypes: environmentTypes,
      preIncidentIndicators: preIncidentIndicators,
      entryIndicators: entryIndicators,
      insideBehaviorIndicators: insideBehaviorIndicators,
      coordinationIndicators: coordinationIndicators,
      deceptionIndicators: deceptionIndicators,
      systemPressureIndicators: systemPressureIndicators,
    );
    return OnyxMoOntologyProfile(
      environmentTypes: environmentTypes,
      incidentType: incidentType,
      behaviorStage: behaviorStage,
      preIncidentIndicators: preIncidentIndicators,
      entryIndicators: entryIndicators,
      insideBehaviorIndicators: insideBehaviorIndicators,
      coordinationIndicators: coordinationIndicators,
      extractionIndicators: extractionIndicators,
      deceptionIndicators: deceptionIndicators,
      systemPressureIndicators: systemPressureIndicators,
      observableCues: observableCues,
      falsePositiveConflicts: falsePositiveConflicts,
      recommendedActionPlans: recommendedActionPlans,
      attackGoal: attackGoal,
      patternConfidence: patternConfidence,
      evidenceQuality: matchedGroups >= 3 ? 'high' : 'medium',
      riskWeight: riskWeight,
      observabilityScore: observabilityScore,
      localRelevanceScore: localRelevanceScore,
      siteTypeOverrides: _siteTypeOverrides(
        environmentTypes: environmentTypes,
        deceptionIndicators: deceptionIndicators,
        preIncidentIndicators: preIncidentIndicators,
      ),
    );
  }

  List<String> _environmentTypes(String text) {
    final matched = <String>[
      if (_hasAny(text, const ['warehouse', 'logistics', 'depot']))
        'warehouse',
      if (_hasAny(text, const ['office', 'business park', 'floor', 'tenant']))
        'office_building',
      if (_hasAny(text, const ['petrol station', 'forecourt', 'fuel']))
        'petrol_station',
      if (_hasAny(text, const ['hotel', 'guest', 'lobby']))
        'hotel',
      if (_hasAny(text, const ['retail', 'shop', 'store', 'mall']))
        'retail',
      if (_hasAny(text, const ['car lot', 'dealership', 'vehicle yard']))
        'car_lot',
    ];
    return matched.isEmpty ? const <String>['generic_site'] : matched;
  }

  List<String> _preIncidentIndicators(String text) {
    return <String>[
      if (_hasAny(text, const ['recon', 'surveyed', 'scouted']))
        'reconnaissance',
      if (_hasAny(text, const ['occupancy', 'checking if anyone', 'schedule']))
        'occupancy_probing',
      if (_hasAny(text, const ['perimeter', 'fence line', 'edge walking']))
        'perimeter_scan',
      if (_hasAny(text, const ['repeat visit', 'returned later', 'came back']))
        'repeat_visitation',
      if (_hasAny(text, const ['camera', 'blind spot', 'mapped cameras']))
        'camera_mapping',
      if (_hasAny(text, const ['loiter', 'lingered', 'waited outside']))
        'loitering',
      if (_hasAny(text, const ['tested schedule', 'shift change']))
        'schedule_testing',
    ];
  }

  List<String> _entryIndicators(String text) {
    return <String>[
      if (_hasAny(text, const ['forced entry', 'broke in', 'pried']))
        'forced_entry',
      if (_hasAny(text, const ['tailgated', 'followed through gate']))
        'tailgating',
      if (_hasAny(text, const ['credential', 'access card', 'badge']))
        'credential_misuse',
      if (_hasAny(text, const ['insider', 'employee assistance']))
        'insider_access',
      if (_hasAny(text, const ['contractor', 'maintenance', 'service uniform']))
        'spoofed_service_access',
      if (_hasAny(text, const ['quiet breach', 'slipped through perimeter']))
        'quiet_perimeter_breach',
      if (_hasAny(text, const ['authorized access', 'abused access']))
        'authorized_access_abuse',
    ];
  }

  List<String> _insideBehaviorIndicators(String text) {
    return <String>[
      if (_hasAny(text, const ['direct path', 'straight to target']))
        'direct_target_pathing',
      if (_hasAny(text, const ['room to room', 'floor to floor', 'multiple floors']))
        'multi_zone_roaming',
      if (_hasAny(text, const [
        'tried several',
        'tried several doors',
        'several doors',
        'restricted doors',
        'door checks',
        'room probing',
      ]))
        'room_probing',
      if (_hasAny(text, const ['shelf sweep', 'grabbed stock']))
        'shelf_sweep',
      if (_hasAny(text, const ['searched compartments', 'opened cabinets']))
        'compartment_search',
      if (_hasAny(text, const ['distract', 'diverted staff']))
        'distraction_behavior',
      if (_hasAny(text, const ['staged items', 'prepositioned']))
        'staging_behavior',
    ];
  }

  List<String> _coordinationIndicators(String text) {
    return <String>[
      if (_hasAny(text, const ['lookout', 'watching outside']))
        'lookout_behavior',
      if (_hasAny(text, const ['team', 'split roles', 'one entered']))
        'split_role_team',
      if (_hasAny(text, const ['two vehicles', 'multiple vehicles']))
        'multi_vehicle_coordination',
      if (_hasAny(text, const ['cross-site', 'another site diversion']))
        'cross_site_distraction',
      if (_hasAny(text, const ['crowd', 'flash crowd', 'overload']))
        'flash_crowd_overload',
    ];
  }

  List<String> _extractionIndicators(String text) {
    return <String>[
      if (_hasAny(text, const ['rapid exit', 'quick getaway', 'ran out']))
        'rapid_extraction',
      if (_hasAny(text, const ['delayed exit', 'waited before leaving']))
        'delayed_exit',
      if (_hasAny(text, const ['same way out', 'same path exit']))
        'same_path_exit',
      if (_hasAny(text, const ['alternate route', 'different exit']))
        'alternate_route_exit',
      if (_hasAny(text, const ['staged transport', 'loaded into vehicle']))
        'staged_transport',
      if (_hasAny(text, const ['drive-off', 'drove away']))
        'drive_off',
    ];
  }

  List<String> _deceptionIndicators(String text) {
    return <String>[
      if (_hasAny(text, const ['staff impersonation', 'pretended to be staff']))
        'staff_impersonation',
      if (_hasAny(text, const ['guest', 'visitor badge']))
        'guest_impersonation',
      if (_hasAny(text, const ['delivery', 'courier', 'parcel']))
        'delivery_impersonation',
      if (_hasAny(text, const ['maintenance', 'contractor', 'service uniform']))
        'maintenance_impersonation',
      if (_hasAny(text, const ['identity drift', 'changed appearance']))
        'identity_drift',
    ];
  }

  List<String> _systemPressureIndicators(String text) {
    return <String>[
      if (_hasAny(text, const ['noise flood', 'alert flood']))
        'noise_flooding',
      if (_hasAny(text, const ['camera tamper', 'covered camera', 'cut camera']))
        'camera_tampering',
      if (_hasAny(text, const ['signal degraded', 'jammed']))
        'signal_degradation',
      if (_hasAny(text, const ['alarm diversion', 'false alarm']))
        'alarm_diversion',
      if (_hasAny(text, const ['comms silence', 'radio silence']))
        'comms_silence',
    ];
  }

  List<String> _observableCues(String text) {
    return <String>[
      if (_hasAny(text, const ['repeat visit', 'came back', 'returned later']))
        'repeat_visits',
      if (_hasAny(text, const ['dwell', 'lingered', 'loiter']))
        'dwell_anomalies',
      if (_hasAny(text, const ['route', 'floor to floor', 'room to room']))
        'route_anomalies',
      if (_hasAny(text, const ['edge walking', 'fence line', 'perimeter']))
        'edge_walking',
      if (_hasAny(text, const ['bag change', 'object change', 'carried out']))
        'bag_or_object_change',
      if (_hasAny(text, const [
        'unauthorized zone',
        'restricted area',
        'restricted door',
        'restricted doors',
      ]))
        'unauthorized_zone_entry',
      if (_hasAny(text, const ['synchronized', 'in step', 'same time']))
        'synchronized_movement',
      if (_hasAny(text, const ['after hours', 'closed site', 'overnight']))
        'after_hours_presence',
    ];
  }

  List<String> _falsePositiveConflicts({
    required List<String> environmentTypes,
    required List<String> preIncidentIndicators,
    required List<String> deceptionIndicators,
  }) {
    return <String>[
      if (environmentTypes.contains('petrol_station') &&
          preIncidentIndicators.contains('loitering'))
        'public_forecourt_dwell',
      if (environmentTypes.contains('hotel') &&
          preIncidentIndicators.contains('repeat_visitation'))
        'guest_arrival_flow',
      if (environmentTypes.contains('office_building') &&
          deceptionIndicators.contains('maintenance_impersonation'))
        'scheduled_contractor_window',
    ];
  }

  List<String> _recommendedActionPlans({
    required List<String> preIncidentIndicators,
    required List<String> entryIndicators,
    required List<String> insideBehaviorIndicators,
    required List<String> coordinationIndicators,
    required List<String> deceptionIndicators,
    required List<String> systemPressureIndicators,
  }) {
    final actions = <String>{
      if (preIncidentIndicators.isNotEmpty) 'PROMOTE SCENE REVIEW',
      if (entryIndicators.isNotEmpty || deceptionIndicators.isNotEmpty)
        'RAISE READINESS',
      if (insideBehaviorIndicators.isNotEmpty || coordinationIndicators.isNotEmpty)
        'PREPOSITION RESPONSE',
      if (systemPressureIndicators.isNotEmpty) 'WATCH SYSTEM PRESSURE',
      if (coordinationIndicators.contains('cross_site_distraction'))
        'SHIFT REGIONAL POSTURE',
    };
    return actions.toList(growable: false);
  }

  String _attackGoal(String text) {
    if (_hasAny(text, const ['steal', 'theft', 'stole', 'devices', 'stock'])) {
      return 'theft';
    }
    if (_hasAny(text, const ['fraud', 'credential', 'impersonation'])) {
      return 'access_abuse';
    }
    if (_hasAny(text, const ['damage', 'sabotage'])) {
      return 'sabotage';
    }
    return 'unknown';
  }

  String _incidentType({
    required String attackGoal,
    required List<String> entryIndicators,
    required List<String> deceptionIndicators,
    required List<String> systemPressureIndicators,
  }) {
    if (deceptionIndicators.isNotEmpty) {
      return 'deception_led_intrusion';
    }
    if (entryIndicators.contains('forced_entry')) {
      return 'forced_intrusion';
    }
    if (systemPressureIndicators.isNotEmpty) {
      return 'system_pressure_event';
    }
    if (attackGoal != 'unknown') {
      return attackGoal;
    }
    return 'suspicious_activity';
  }

  String _behaviorStage({
    required List<String> preIncidentIndicators,
    required List<String> entryIndicators,
    required List<String> insideBehaviorIndicators,
    required List<String> extractionIndicators,
  }) {
    if (extractionIndicators.isNotEmpty) {
      return 'extraction';
    }
    if (insideBehaviorIndicators.isNotEmpty) {
      return 'inside_behavior';
    }
    if (entryIndicators.isNotEmpty) {
      return 'entry';
    }
    if (preIncidentIndicators.isNotEmpty) {
      return 'pre_incident';
    }
    return 'unknown';
  }

  int _riskWeight({
    required List<String> environmentTypes,
    required List<String> preIncidentIndicators,
    required List<String> entryIndicators,
    required List<String> insideBehaviorIndicators,
    required List<String> coordinationIndicators,
    required List<String> deceptionIndicators,
    required List<String> systemPressureIndicators,
  }) {
    var weight = 20;
    weight += preIncidentIndicators.length * 4;
    weight += entryIndicators.length * 8;
    weight += insideBehaviorIndicators.length * 7;
    weight += coordinationIndicators.length * 5;
    weight += deceptionIndicators.length * 8;
    weight += systemPressureIndicators.length * 6;
    if (environmentTypes.contains('warehouse') ||
        environmentTypes.contains('car_lot')) {
      weight += 8;
    }
    if (environmentTypes.contains('office_building') &&
        deceptionIndicators.contains('maintenance_impersonation')) {
      weight += 10;
    }
    if (weight > 100) {
      return 100;
    }
    return weight;
  }

  Map<String, int> _siteTypeOverrides({
    required List<String> environmentTypes,
    required List<String> deceptionIndicators,
    required List<String> preIncidentIndicators,
  }) {
    final overrides = <String, int>{};
    for (final environmentType in environmentTypes) {
      var weight = 50;
      if (environmentType == 'warehouse') {
        weight += 15;
      }
      if (environmentType == 'car_lot') {
        weight += 12;
      }
      if (environmentType == 'petrol_station' &&
          preIncidentIndicators.contains('loitering')) {
        weight -= 15;
      }
      if (environmentType == 'office_building' &&
          deceptionIndicators.contains('maintenance_impersonation')) {
        weight += 20;
      }
      overrides[environmentType] = weight;
    }
    return overrides;
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  double _bounded(double value) {
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }
}
