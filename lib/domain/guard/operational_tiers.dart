enum GuardOperationalTier {
  tier1VerifiedOperations,
  tier2EvidenceGuard,
  tier3IntelligenceGuard,
}

enum GuardCapability {
  pttVoice,
  dispatchAck,
  gpsTracking,
  statusUpdates,
  panicAlert,
  pushNotifications,
  incidentPhotoCapture,
  nfcCheckpointTagging,
  patrolComplianceMonitoring,
  patrolProofVerification,
  missedCheckpointAlerts,
  mandatoryPatrolVerificationImages,
  incidentVideoCapture,
  evidenceChain,
  mediaUploadNearLive,
  supervisorMonitoring,
  environmentalMonitoring,
  predictiveInsights,
}

enum GuardDeviceUpgrade {
  ruggedCaseProtection,
  beltHolster,
  chestMountHarness,
  powerBankSupport,
  upgradedStorage,
  enhancedCamera,
  enhancedMicrophone,
  highBandwidth4g,
  preferred5g,
  nightCapability,
  supervisorTabletOptional,
}

enum WearableCapability {
  heartRateMonitoring,
  activityDetection,
  movementDetection,
  devicePairing,
  stressIndicatorsOptional,
  inactivityDetectionOptional,
  motionSpikeDetectionOptional,
}

class GuardTierProfile {
  final GuardOperationalTier tier;
  final String label;
  final String purpose;
  final Set<GuardCapability> capabilities;
  final Set<GuardDeviceUpgrade> deviceUpgrades;
  final Set<WearableCapability> wearableCapabilities;
  final bool nfcCheckpointingMandatory;
  final bool bodyCameraOrEventVideoEnabled;
  final bool aiEnvironmentalMonitoringEnabled;

  const GuardTierProfile({
    required this.tier,
    required this.label,
    required this.purpose,
    required this.capabilities,
    required this.deviceUpgrades,
    required this.wearableCapabilities,
    required this.nfcCheckpointingMandatory,
    required this.bodyCameraOrEventVideoEnabled,
    required this.aiEnvironmentalMonitoringEnabled,
  });
}

class GuardOperationalTierCatalog {
  static const Set<GuardCapability> _tier1BaseCapabilities = {
    GuardCapability.pttVoice,
    GuardCapability.dispatchAck,
    GuardCapability.gpsTracking,
    GuardCapability.statusUpdates,
    GuardCapability.panicAlert,
    GuardCapability.pushNotifications,
    GuardCapability.incidentPhotoCapture,
    GuardCapability.nfcCheckpointTagging,
    GuardCapability.patrolComplianceMonitoring,
    GuardCapability.patrolProofVerification,
    GuardCapability.missedCheckpointAlerts,
    GuardCapability.mandatoryPatrolVerificationImages,
  };

  static const Set<GuardDeviceUpgrade> _tier1DeviceUpgrades = {
    GuardDeviceUpgrade.ruggedCaseProtection,
    GuardDeviceUpgrade.beltHolster,
    GuardDeviceUpgrade.powerBankSupport,
  };

  static const Set<GuardDeviceUpgrade> _tier2DeviceUpgrades = {
    GuardDeviceUpgrade.ruggedCaseProtection,
    GuardDeviceUpgrade.beltHolster,
    GuardDeviceUpgrade.chestMountHarness,
    GuardDeviceUpgrade.powerBankSupport,
    GuardDeviceUpgrade.upgradedStorage,
    GuardDeviceUpgrade.enhancedCamera,
    GuardDeviceUpgrade.enhancedMicrophone,
    GuardDeviceUpgrade.highBandwidth4g,
  };

  static const Set<GuardDeviceUpgrade> _tier3DeviceUpgrades = {
    GuardDeviceUpgrade.ruggedCaseProtection,
    GuardDeviceUpgrade.beltHolster,
    GuardDeviceUpgrade.chestMountHarness,
    GuardDeviceUpgrade.powerBankSupport,
    GuardDeviceUpgrade.upgradedStorage,
    GuardDeviceUpgrade.enhancedCamera,
    GuardDeviceUpgrade.enhancedMicrophone,
    GuardDeviceUpgrade.highBandwidth4g,
    GuardDeviceUpgrade.preferred5g,
    GuardDeviceUpgrade.nightCapability,
    GuardDeviceUpgrade.supervisorTabletOptional,
  };

  static const Set<WearableCapability> _standardWearableCapabilities = {
    WearableCapability.heartRateMonitoring,
    WearableCapability.activityDetection,
    WearableCapability.movementDetection,
    WearableCapability.devicePairing,
    WearableCapability.stressIndicatorsOptional,
    WearableCapability.inactivityDetectionOptional,
    WearableCapability.motionSpikeDetectionOptional,
  };

  static GuardTierProfile profile(GuardOperationalTier tier) {
    return switch (tier) {
      GuardOperationalTier.tier1VerifiedOperations => GuardTierProfile(
        tier: tier,
        label: 'ONYX Guard',
        purpose:
            'Verified operations baseline with auditable patrol discipline.',
        capabilities: _tier1BaseCapabilities,
        deviceUpgrades: _tier1DeviceUpgrades,
        wearableCapabilities: _standardWearableCapabilities,
        nfcCheckpointingMandatory: true,
        bodyCameraOrEventVideoEnabled: false,
        aiEnvironmentalMonitoringEnabled: false,
      ),
      GuardOperationalTier.tier2EvidenceGuard => GuardTierProfile(
        tier: tier,
        label: 'ONYX Evidence Guard',
        purpose:
            'Evidence-grade operations with stronger incident accountability.',
        capabilities: {
          ..._tier1BaseCapabilities,
          GuardCapability.incidentVideoCapture,
          GuardCapability.evidenceChain,
          GuardCapability.mediaUploadNearLive,
          GuardCapability.supervisorMonitoring,
        },
        deviceUpgrades: _tier2DeviceUpgrades,
        wearableCapabilities: _standardWearableCapabilities,
        nfcCheckpointingMandatory: true,
        bodyCameraOrEventVideoEnabled: true,
        aiEnvironmentalMonitoringEnabled: false,
      ),
      GuardOperationalTier.tier3IntelligenceGuard => GuardTierProfile(
        tier: tier,
        label: 'ONYX Intelligence Guard',
        purpose:
            'Intelligence-led monitoring with predictive threat awareness.',
        capabilities: {
          ..._tier1BaseCapabilities,
          GuardCapability.incidentVideoCapture,
          GuardCapability.evidenceChain,
          GuardCapability.mediaUploadNearLive,
          GuardCapability.supervisorMonitoring,
          GuardCapability.environmentalMonitoring,
          GuardCapability.predictiveInsights,
        },
        deviceUpgrades: _tier3DeviceUpgrades,
        wearableCapabilities: _standardWearableCapabilities,
        nfcCheckpointingMandatory: true,
        bodyCameraOrEventVideoEnabled: true,
        aiEnvironmentalMonitoringEnabled: true,
      ),
    };
  }
}
