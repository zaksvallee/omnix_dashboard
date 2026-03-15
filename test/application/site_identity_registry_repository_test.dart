import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/site_identity_registry_repository.dart';

void main() {
  test('site identity profile normalizes to a Supabase upsert row', () {
    final profile = SiteIdentityProfile(
      profileId: 'profile-1',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      identityType: SiteIdentityType.person,
      category: SiteIdentityCategory.visitor,
      status: SiteIdentityStatus.allowed,
      displayName: 'John Visitor',
      faceMatchId: 'PERSON-44',
      externalReference: 'telegram-intake-1',
      validFromUtc: DateTime.utc(2026, 3, 15, 10),
      validUntilUtc: DateTime.utc(2026, 3, 15, 18),
      createdAtUtc: DateTime.utc(2026, 3, 15, 9),
      updatedAtUtc: DateTime.utc(2026, 3, 15, 9, 5),
      metadata: const <String, Object?>{'source': 'telegram'},
    );

    expect(profile.hasStableIdentity, isTrue);
    expect(profile.toUpsertRow(), <String, Object?>{
      'id': 'profile-1',
      'client_id': 'CLIENT-MS-VALLEE',
      'site_id': 'SITE-MS-VALLEE-RESIDENCE',
      'identity_type': 'person',
      'category': 'visitor',
      'status': 'allowed',
      'display_name': 'John Visitor',
      'face_match_id': 'PERSON-44',
      'plate_number': null,
      'external_reference': 'telegram-intake-1',
      'notes': null,
      'valid_from': '2026-03-15T10:00:00.000Z',
      'valid_until': '2026-03-15T18:00:00.000Z',
      'metadata': const <String, Object?>{'source': 'telegram'},
    });
  });

  test('site identity profile parses from a Supabase row', () {
    final profile = SiteIdentityProfile.fromRow(<String, Object?>{
      'id': 'profile-2',
      'client_id': 'CLIENT-MS-VALLEE',
      'site_id': 'SITE-MS-VALLEE-RESIDENCE',
      'identity_type': 'vehicle',
      'category': 'family',
      'status': 'allowed',
      'display_name': 'Grey Fortuner',
      'face_match_id': '',
      'plate_number': 'CA123456',
      'external_reference': 'manual',
      'notes': 'Family vehicle',
      'valid_from': '2026-03-15T10:00:00.000Z',
      'valid_until': null,
      'created_at': '2026-03-15T09:00:00.000Z',
      'updated_at': '2026-03-15T09:10:00.000Z',
      'metadata': <String, Object?>{'lane': 'gate'},
    });

    expect(profile.identityType, SiteIdentityType.vehicle);
    expect(profile.category, SiteIdentityCategory.family);
    expect(profile.status, SiteIdentityStatus.allowed);
    expect(profile.plateNumber, 'CA123456');
    expect(profile.metadata['lane'], 'gate');
  });

  test('approval decision serializes to an insert row', () {
    final record = SiteIdentityApprovalDecisionRecord(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      profileId: 'profile-1',
      intelligenceId: 'INTEL-77',
      decision: SiteIdentityDecision.approveAlways,
      source: SiteIdentityDecisionSource.telegram,
      decidedBy: '@resident',
      decisionSummary:
          'Client approved permanent allowlisting for the visitor.',
      decidedAtUtc: DateTime.utc(2026, 3, 15, 11, 30),
    );

    expect(record.toInsertRow(), <String, Object?>{
      'client_id': 'CLIENT-MS-VALLEE',
      'site_id': 'SITE-MS-VALLEE-RESIDENCE',
      'profile_id': 'profile-1',
      'intelligence_id': 'INTEL-77',
      'decision': 'approve_always',
      'source': 'telegram',
      'decided_by': '@resident',
      'decision_summary':
          'Client approved permanent allowlisting for the visitor.',
      'decided_at': '2026-03-15T11:30:00.000Z',
      'metadata': const <String, Object?>{},
    });
  });

  test('telegram intake serializes parsed visitor proposal fields', () {
    final intake = TelegramIdentityIntakeRecord(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      endpointId: 'endpoint-1',
      rawText: 'John Smith is visiting in a white Hilux CA123456 until 18:00',
      parsedDisplayName: 'John Smith',
      parsedPlateNumber: 'CA123456',
      category: SiteIdentityCategory.visitor,
      aiConfidence: 0.92,
      approvalState: 'proposed',
      createdAtUtc: DateTime.utc(2026, 3, 15, 10, 45),
    );

    expect(intake.toInsertRow(), <String, Object?>{
      'client_id': 'CLIENT-MS-VALLEE',
      'site_id': 'SITE-MS-VALLEE-RESIDENCE',
      'endpoint_id': 'endpoint-1',
      'raw_text':
          'John Smith is visiting in a white Hilux CA123456 until 18:00',
      'parsed_display_name': 'John Smith',
      'parsed_face_match_id': null,
      'parsed_plate_number': 'CA123456',
      'parsed_category': 'visitor',
      'valid_from': null,
      'valid_until': null,
      'ai_confidence': 0.92,
      'approval_state': 'proposed',
      'created_at': '2026-03-15T10:45:00.000Z',
      'metadata': const <String, Object?>{},
    });
  });

  test('telegram intake parses from a Supabase row', () {
    final intake = TelegramIdentityIntakeRecord.fromRow(<String, Object?>{
      'id': 'intake-1',
      'client_id': 'CLIENT-MS-VALLEE',
      'site_id': 'SITE-MS-VALLEE-RESIDENCE',
      'endpoint_id': 'endpoint-1',
      'raw_text': 'John Smith in white Hilux CA123456 until 18:00',
      'parsed_display_name': 'John Smith',
      'parsed_face_match_id': 'PERSON-44',
      'parsed_plate_number': 'CA123456',
      'parsed_category': 'visitor',
      'valid_from': '2026-03-15T10:00:00.000Z',
      'valid_until': '2026-03-15T18:00:00.000Z',
      'ai_confidence': 0.88,
      'approval_state': 'proposed',
      'created_at': '2026-03-15T09:55:00.000Z',
      'metadata': <String, Object?>{'source': 'telegram'},
    });

    expect(intake.intakeId, 'intake-1');
    expect(intake.parsedDisplayName, 'John Smith');
    expect(intake.parsedFaceMatchId, 'PERSON-44');
    expect(intake.parsedPlateNumber, 'CA123456');
    expect(intake.category, SiteIdentityCategory.visitor);
    expect(intake.approvalState, 'proposed');
    expect(intake.metadata['source'], 'telegram');
  });
}
