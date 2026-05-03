enum ZaraAllowanceTier { standard, premium, tactical }

enum ZaraCapabilityCategory { conversational, analytics, intelligence }

class ZaraCapabilityDefinition {
  final String capabilityKey;
  final String displayName;
  final ZaraCapabilityCategory category;
  final String upsellBlurb;
  final String upsellCta;
  final String? requiresDataSource;

  const ZaraCapabilityDefinition({
    required this.capabilityKey,
    required this.displayName,
    required this.category,
    required this.upsellBlurb,
    required this.upsellCta,
    this.requiresDataSource,
  });

  Map<String, Object?> toRow() {
    return <String, Object?>{
      'capability_key': capabilityKey,
      'display_name': displayName,
      'category': category.name,
      'upsell_blurb': upsellBlurb,
      'upsell_cta': upsellCta,
      'requires_data_source': requiresDataSource,
    };
  }
}

const List<ZaraCapabilityDefinition>
zaraCapabilityRegistry = <ZaraCapabilityDefinition>[
  ZaraCapabilityDefinition(
    capabilityKey: 'monitoring_status_brief',
    displayName: 'Monitoring Status Brief',
    category: ZaraCapabilityCategory.conversational,
    upsellBlurb:
        'Monitoring status briefs are already available on ONYX live-monitoring sites.',
    upsellCta: 'feature_sheet',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'incident_summary_reply',
    displayName: 'Incident Summary Reply',
    category: ZaraCapabilityCategory.conversational,
    upsellBlurb:
        'Incident summary replies are already available when the incident context is in lane.',
    upsellCta: 'feature_sheet',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'report_narrative_draft',
    displayName: 'Report Narrative Draft',
    category: ZaraCapabilityCategory.intelligence,
    upsellBlurb:
        'Report narrative drafts need the report bundle activated for this site. I can flag that through your account manager if helpful.',
    upsellCta: 'account_manager',
    requiresDataSource: 'report_bundle',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'dispatch_triage',
    displayName: 'Dispatch Triage',
    category: ZaraCapabilityCategory.intelligence,
    upsellBlurb:
        'Dispatch triage needs dispatch event history activated for this site. I can flag that through your account manager if helpful.',
    upsellCta: 'account_manager',
    requiresDataSource: 'dispatch_events',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'incident_notes',
    displayName: 'Incident Notes Timeline',
    category: ZaraCapabilityCategory.conversational,
    upsellBlurb:
        'Incident-note timelines need incident notes activated for this site. I can flag that through your account manager if helpful.',
    upsellCta: 'account_manager',
    requiresDataSource: 'incident_notes',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'guard_shift_roster_brief',
    displayName: 'Guard Shift Roster Brief',
    category: ZaraCapabilityCategory.analytics,
    upsellBlurb:
        'Guard shift roster briefs need shift coverage activated for this site. I can flag that through your account manager if helpful.',
    upsellCta: 'account_manager',
    requiresDataSource: 'shift_instances',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'peak_occupancy',
    displayName: 'Peak Occupancy',
    category: ZaraCapabilityCategory.analytics,
    upsellBlurb:
        'Peak occupancy needs the CV pipeline occupancy feed activated for this site. I can flag that through your account manager if helpful.',
    upsellCta: 'account_manager',
    requiresDataSource: 'cv_pipeline_occupancy',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'face_registry_lookup',
    displayName: 'Face Registry Lookup',
    category: ZaraCapabilityCategory.intelligence,
    upsellBlurb:
        'Face-registry lookups need face-registry matching activated for this site. I can flag that through your account manager if helpful.',
    upsellCta: 'account_manager',
    requiresDataSource: 'fr_person_registry',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'vehicle_pattern_analysis',
    displayName: 'Vehicle Pattern Analysis',
    category: ZaraCapabilityCategory.analytics,
    upsellBlurb:
        'Vehicle pattern analysis needs vehicle analytics activated for this site. I can flag that through your account manager if helpful.',
    upsellCta: 'account_manager',
    requiresDataSource: 'bi_vehicle_persistence',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'theatre_action_orchestration',
    displayName: 'Theatre Action Orchestration',
    category: ZaraCapabilityCategory.intelligence,
    upsellBlurb:
        'Theatre action orchestration needs Zara scenarios activated for this site. I can flag that through your account manager if helpful.',
    upsellCta: 'account_manager',
    requiresDataSource: 'zara_scenarios',
  ),
];

ZaraCapabilityDefinition? zaraCapabilityByKey(String capabilityKey) {
  final normalized = capabilityKey.trim().toLowerCase();
  for (final capability in zaraCapabilityRegistry) {
    if (capability.capabilityKey == normalized) {
      return capability;
    }
  }
  return null;
}

ZaraAllowanceTier? parseZaraAllowanceTier(Object? rawTier) {
  final normalized = rawTier?.toString().trim().toLowerCase() ?? '';
  return switch (normalized) {
    'standard' => ZaraAllowanceTier.standard,
    'premium' => ZaraAllowanceTier.premium,
    'tactical' => ZaraAllowanceTier.tactical,
    _ => null,
  };
}

bool zaraCapabilityHasDataSource({
  required ZaraCapabilityDefinition capability,
  required Iterable<String> activeDataSources,
}) {
  final requiredDataSource = capability.requiresDataSource?.trim();
  if (requiredDataSource == null || requiredDataSource.isEmpty) {
    return true;
  }
  final available = activeDataSources
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet();
  return available.contains(requiredDataSource);
}

String zaraCapabilityUpsellMessage({
  required ZaraCapabilityDefinition capability,
}) {
  return capability.upsellBlurb;
}

String zaraCapabilityDataSourceMessage({
  required ZaraCapabilityDefinition capability,
}) {
  final dataSource = capability.requiresDataSource?.trim();
  if (dataSource == null || dataSource.isEmpty) {
    return capability.upsellBlurb;
  }
  return capability.upsellBlurb;
}

String zaraAllowanceTierLabel(ZaraAllowanceTier tier) {
  return switch (tier) {
    ZaraAllowanceTier.standard => 'Standard',
    ZaraAllowanceTier.premium => 'Premium',
    ZaraAllowanceTier.tactical => 'Tactical',
  };
}
