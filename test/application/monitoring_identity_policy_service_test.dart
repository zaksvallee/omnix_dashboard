import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_identity_policy_service.dart';

void main() {
  test('parses site-level allowed and flagged face and plate rules', () {
    final service = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["resident-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["ca111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    final policy = service.policyFor(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(policy.matchesAllowedFace('RESIDENT-01'), isTrue);
    expect(policy.matchesFlaggedFace('person-44'), isTrue);
    expect(policy.matchesAllowedPlate('CA111111'), isTrue);
    expect(policy.matchesFlaggedPlate('ca123456'), isTrue);
    expect(policy.matchesFlaggedPlate('CA000000'), isFalse);
  });

  test('serializes canonical identity policy JSON', () {
    final service = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["resident-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["ca111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    expect(
      service.toCanonicalJsonString(),
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );
  });
}
