import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_temporary_identity_approval_service.dart';
import 'package:omnix_dashboard/application/site_identity_registry_repository.dart';

void main() {
  test('matches active temporary approval by face and plate until expiry', () {
    final service = MonitoringTemporaryIdentityApprovalService.fromProfiles([
      SiteIdentityProfile(
        profileId: 'profile-1',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        identityType: SiteIdentityType.person,
        category: SiteIdentityCategory.visitor,
        status: SiteIdentityStatus.allowed,
        displayName: 'John Visitor',
        faceMatchId: 'PERSON-44',
        plateNumber: 'CA123456',
        validFromUtc: DateTime.utc(2026, 3, 15, 9),
        validUntilUtc: DateTime.utc(2026, 3, 15, 18),
        createdAtUtc: DateTime.utc(2026, 3, 15, 9),
        updatedAtUtc: DateTime.utc(2026, 3, 15, 9),
      ),
    ]);

    final match = service.matchAllowed(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      faceMatchId: 'PERSON-44',
      plateNumber: 'CA123456',
      atUtc: DateTime.utc(2026, 3, 15, 12),
    );

    expect(match.matched, isTrue);
    expect(match.matchedFace, isTrue);
    expect(match.matchedPlate, isTrue);
    expect(match.validUntilUtc, DateTime.utc(2026, 3, 15, 18));
  });

  test('ignores expired temporary approvals', () {
    final service = MonitoringTemporaryIdentityApprovalService.fromProfiles([
      SiteIdentityProfile(
        profileId: 'profile-1',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        identityType: SiteIdentityType.vehicle,
        category: SiteIdentityCategory.visitor,
        status: SiteIdentityStatus.allowed,
        displayName: 'CA123456',
        plateNumber: 'CA123456',
        validFromUtc: DateTime.utc(2026, 3, 15, 9),
        validUntilUtc: DateTime.utc(2026, 3, 15, 10),
        createdAtUtc: DateTime.utc(2026, 3, 15, 9),
        updatedAtUtc: DateTime.utc(2026, 3, 15, 9),
      ),
    ]);

    final match = service.matchAllowed(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      plateNumber: 'CA123456',
      atUtc: DateTime.utc(2026, 3, 15, 12),
    );

    expect(match.matched, isFalse);
  });
}
