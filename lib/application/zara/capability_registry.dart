enum ZaraCapabilityTier { standard, premium, tactical }

enum ZaraCapabilityCategory { conversational, analytics, intelligence }

class ZaraCapabilityDefinition {
  final String capabilityKey;
  final ZaraCapabilityTier minTier;
  final String displayName;
  final ZaraCapabilityCategory category;
  final String upsellBlurb;
  final String upsellCta;
  final String? requiresDataSource;

  const ZaraCapabilityDefinition({
    required this.capabilityKey,
    required this.minTier,
    required this.displayName,
    required this.category,
    required this.upsellBlurb,
    required this.upsellCta,
    this.requiresDataSource,
  });

  Map<String, Object?> toRow() {
    return <String, Object?>{
      'capability_key': capabilityKey,
      'min_tier': minTier.name,
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
    minTier: ZaraCapabilityTier.standard,
    displayName: 'Monitoring Status Brief',
    category: ZaraCapabilityCategory.conversational,
    upsellBlurb:
        'I can keep the monitoring brief in the Standard lane. No upgrade needed here.',
    upsellCta: 'feature_sheet',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'incident_summary_reply',
    minTier: ZaraCapabilityTier.standard,
    displayName: 'Incident Summary Reply',
    category: ZaraCapabilityCategory.conversational,
    upsellBlurb:
        'I can draft the incident summary in the Standard lane. No upgrade needed here.',
    upsellCta: 'feature_sheet',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'report_narrative_draft',
    minTier: ZaraCapabilityTier.standard,
    displayName: 'Report Narrative Draft',
    category: ZaraCapabilityCategory.intelligence,
    upsellBlurb:
        'I can draft the report narrative in the Standard lane. No upgrade needed here.',
    upsellCta: 'feature_sheet',
    requiresDataSource: 'report_bundle',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'dispatch_triage',
    minTier: ZaraCapabilityTier.premium,
    displayName: 'Dispatch Triage',
    category: ZaraCapabilityCategory.intelligence,
    upsellBlurb:
        'I can take dispatch triage further once Premium intelligence is switched on for this site.',
    upsellCta: 'sales_call',
    requiresDataSource: 'dispatch_events',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'incident_notes',
    minTier: ZaraCapabilityTier.premium,
    displayName: 'Incident Notes Timeline',
    category: ZaraCapabilityCategory.conversational,
    upsellBlurb:
        'I can work the incident-note timeline properly once Premium intelligence is active for this site.',
    upsellCta: 'feature_sheet',
    requiresDataSource: 'incident_notes',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'guard_shift_roster_brief',
    minTier: ZaraCapabilityTier.premium,
    displayName: 'Guard Shift Roster Brief',
    category: ZaraCapabilityCategory.analytics,
    upsellBlurb:
        'I can brief against the live roster once Premium intelligence is enabled for the guard workflow.',
    upsellCta: 'feature_sheet',
    requiresDataSource: 'shift_instances',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'footfall_count',
    minTier: ZaraCapabilityTier.tactical,
    displayName: 'Footfall Count',
    category: ZaraCapabilityCategory.analytics,
    upsellBlurb:
        'Footfall analytics sit in Tactical. I can help there once Tactical is enabled for this site.',
    upsellCta: 'sales_call',
    requiresDataSource: 'cv_pipeline_footfall',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'face_registry_lookup',
    minTier: ZaraCapabilityTier.tactical,
    displayName: 'Face Registry Lookup',
    category: ZaraCapabilityCategory.intelligence,
    upsellBlurb:
        'Face-registry lookups sit in Tactical. I can handle that once Tactical is enabled for this site.',
    upsellCta: 'sales_call',
    requiresDataSource: 'fr_person_registry',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'vehicle_pattern_analysis',
    minTier: ZaraCapabilityTier.tactical,
    displayName: 'Vehicle Pattern Analysis',
    category: ZaraCapabilityCategory.analytics,
    upsellBlurb:
        'Vehicle-pattern analysis sits in Tactical. I can handle that once Tactical is enabled for this site.',
    upsellCta: 'sales_call',
    requiresDataSource: 'bi_vehicle_persistence',
  ),
  ZaraCapabilityDefinition(
    capabilityKey: 'theatre_action_orchestration',
    minTier: ZaraCapabilityTier.tactical,
    displayName: 'Theatre Action Orchestration',
    category: ZaraCapabilityCategory.intelligence,
    upsellBlurb:
        'Multi-step theatre orchestration sits in Tactical. I can take that on once Tactical is enabled for this site.',
    upsellCta: 'sales_call',
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

bool zaraTierAllowsCapability({
  required ZaraCapabilityTier activeTier,
  required ZaraCapabilityDefinition capability,
}) {
  return _tierRank(activeTier) >= _tierRank(capability.minTier);
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
  required ZaraCapabilityTier activeTier,
}) {
  return '${capability.upsellBlurb} Active tier: ${zaraTierLabel(activeTier)}. Required tier: ${zaraTierLabel(capability.minTier)}.';
}

String zaraTierLabel(ZaraCapabilityTier tier) {
  return switch (tier) {
    ZaraCapabilityTier.standard => 'Standard',
    ZaraCapabilityTier.premium => 'Premium',
    ZaraCapabilityTier.tactical => 'Tactical',
  };
}

int _tierRank(ZaraCapabilityTier tier) {
  return switch (tier) {
    ZaraCapabilityTier.standard => 1,
    ZaraCapabilityTier.premium => 2,
    ZaraCapabilityTier.tactical => 3,
  };
}
