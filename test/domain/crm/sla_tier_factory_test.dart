import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/crm/sla_profile.dart';
import 'package:omnix_dashboard/domain/crm/sla_tier.dart';
import 'package:omnix_dashboard/domain/crm/sla_tier_factory.dart';

void _expectUtcTimestamp(SLAProfile profile) {
  expect(DateTime.parse(profile.createdAt).isUtc, isTrue);
}

void main() {
  group('SLATierFactory.create', () {
    test('builds the core profile with the expected minute thresholds', () {
      final profile = SLATierFactory.create(
        clientId: 'CLIENT-1',
        tier: SLATier.core,
      );

      expect(profile.slaId, 'SLA-CLIENT-1-core');
      expect(profile.lowMinutes, 180);
      expect(profile.mediumMinutes, 90);
      expect(profile.highMinutes, 45);
      expect(profile.criticalMinutes, 20);
      expect(profile.lowWeight, 1.0);
      expect(profile.mediumWeight, 1.5);
      expect(profile.highWeight, 2.0);
      expect(profile.criticalWeight, 3.0);
      _expectUtcTimestamp(profile);
    });

    test('builds the protect profile stricter than core', () {
      final core = SLATierFactory.create(
        clientId: 'CLIENT-1',
        tier: SLATier.core,
      );
      final protect = SLATierFactory.create(
        clientId: 'CLIENT-1',
        tier: SLATier.protect,
      );

      expect(protect.slaId, 'SLA-CLIENT-1-protect');
      expect(protect.lowMinutes, lessThan(core.lowMinutes));
      expect(protect.mediumMinutes, lessThan(core.mediumMinutes));
      expect(protect.highMinutes, lessThan(core.highMinutes));
      expect(protect.criticalMinutes, lessThan(core.criticalMinutes));
      expect(protect.criticalWeight, greaterThan(core.criticalWeight));
      _expectUtcTimestamp(protect);
    });

    test('builds the sovereign profile as the strictest tier', () {
      final protect = SLATierFactory.create(
        clientId: 'CLIENT-1',
        tier: SLATier.protect,
      );
      final sovereign = SLATierFactory.create(
        clientId: 'CLIENT-X',
        tier: SLATier.sovereign,
      );

      expect(sovereign.slaId, 'SLA-CLIENT-X-sovereign');
      expect(sovereign.lowMinutes, lessThan(protect.lowMinutes));
      expect(sovereign.mediumMinutes, lessThan(protect.mediumMinutes));
      expect(sovereign.highMinutes, lessThan(protect.highMinutes));
      expect(sovereign.criticalMinutes, lessThan(protect.criticalMinutes));
      expect(sovereign.lowWeight, 1.0);
      expect(sovereign.mediumWeight, 3.0);
      expect(sovereign.highWeight, 5.0);
      expect(sovereign.criticalWeight, 8.0);
      _expectUtcTimestamp(sovereign);
    });
  });
}
