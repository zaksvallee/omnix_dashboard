import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/guard/operational_tiers.dart';

void main() {
  test('tier 1 baseline includes mandatory patrol verification', () {
    final profile = GuardOperationalTierCatalog.profile(
      GuardOperationalTier.tier1VerifiedOperations,
    );

    expect(profile.label, 'ONYX Guard');
    expect(profile.nfcCheckpointingMandatory, isTrue);
    expect(profile.bodyCameraOrEventVideoEnabled, isFalse);
    expect(profile.capabilities, contains(GuardCapability.nfcCheckpointTagging));
    expect(
      profile.capabilities,
      contains(GuardCapability.mandatoryPatrolVerificationImages),
    );
    expect(profile.capabilities, isNot(contains(GuardCapability.incidentVideoCapture)));
  });

  test('tier 2 extends baseline with evidence capture', () {
    final profile = GuardOperationalTierCatalog.profile(
      GuardOperationalTier.tier2EvidenceGuard,
    );

    expect(profile.label, 'ONYX Evidence Guard');
    expect(profile.nfcCheckpointingMandatory, isTrue);
    expect(profile.bodyCameraOrEventVideoEnabled, isTrue);
    expect(profile.aiEnvironmentalMonitoringEnabled, isFalse);
    expect(profile.capabilities, contains(GuardCapability.incidentVideoCapture));
    expect(profile.capabilities, contains(GuardCapability.evidenceChain));
    expect(profile.capabilities, contains(GuardCapability.mediaUploadNearLive));
  });

  test('tier 3 enables intelligence monitoring capabilities', () {
    final profile = GuardOperationalTierCatalog.profile(
      GuardOperationalTier.tier3IntelligenceGuard,
    );

    expect(profile.label, 'ONYX Intelligence Guard');
    expect(profile.nfcCheckpointingMandatory, isTrue);
    expect(profile.bodyCameraOrEventVideoEnabled, isTrue);
    expect(profile.aiEnvironmentalMonitoringEnabled, isTrue);
    expect(
      profile.capabilities,
      contains(GuardCapability.environmentalMonitoring),
    );
    expect(profile.capabilities, contains(GuardCapability.predictiveInsights));
    expect(profile.deviceUpgrades, contains(GuardDeviceUpgrade.preferred5g));
  });

  test('all tiers include wearable safety baseline', () {
    for (final tier in GuardOperationalTier.values) {
      final profile = GuardOperationalTierCatalog.profile(tier);
      expect(
        profile.wearableCapabilities,
        contains(WearableCapability.heartRateMonitoring),
      );
      expect(
        profile.wearableCapabilities,
        contains(WearableCapability.activityDetection),
      );
      expect(
        profile.wearableCapabilities,
        contains(WearableCapability.devicePairing),
      );
    }
  });
}
