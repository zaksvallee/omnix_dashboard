import 'package:supabase_flutter/supabase_flutter.dart';

enum SiteIdentityType { person, vehicle }

extension SiteIdentityTypeX on SiteIdentityType {
  String get code {
    return switch (this) {
      SiteIdentityType.person => 'person',
      SiteIdentityType.vehicle => 'vehicle',
    };
  }

  static SiteIdentityType fromCode(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'vehicle' => SiteIdentityType.vehicle,
      _ => SiteIdentityType.person,
    };
  }
}

enum SiteIdentityStatus { allowed, flagged, pending, expired }

extension SiteIdentityStatusX on SiteIdentityStatus {
  String get code {
    return switch (this) {
      SiteIdentityStatus.allowed => 'allowed',
      SiteIdentityStatus.flagged => 'flagged',
      SiteIdentityStatus.pending => 'pending',
      SiteIdentityStatus.expired => 'expired',
    };
  }

  static SiteIdentityStatus fromCode(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'flagged' => SiteIdentityStatus.flagged,
      'pending' => SiteIdentityStatus.pending,
      'expired' => SiteIdentityStatus.expired,
      _ => SiteIdentityStatus.allowed,
    };
  }
}

enum SiteIdentityCategory {
  employee,
  family,
  resident,
  visitor,
  contractor,
  delivery,
  unknown,
}

extension SiteIdentityCategoryX on SiteIdentityCategory {
  String get code {
    return switch (this) {
      SiteIdentityCategory.employee => 'employee',
      SiteIdentityCategory.family => 'family',
      SiteIdentityCategory.resident => 'resident',
      SiteIdentityCategory.visitor => 'visitor',
      SiteIdentityCategory.contractor => 'contractor',
      SiteIdentityCategory.delivery => 'delivery',
      SiteIdentityCategory.unknown => 'unknown',
    };
  }

  static SiteIdentityCategory fromCode(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'employee' => SiteIdentityCategory.employee,
      'family' => SiteIdentityCategory.family,
      'resident' => SiteIdentityCategory.resident,
      'visitor' => SiteIdentityCategory.visitor,
      'contractor' => SiteIdentityCategory.contractor,
      'delivery' => SiteIdentityCategory.delivery,
      _ => SiteIdentityCategory.unknown,
    };
  }
}

enum SiteIdentityDecision {
  approveOnce,
  approveAlways,
  review,
  escalate,
  revoke,
}

extension SiteIdentityDecisionX on SiteIdentityDecision {
  String get code {
    return switch (this) {
      SiteIdentityDecision.approveOnce => 'approve_once',
      SiteIdentityDecision.approveAlways => 'approve_always',
      SiteIdentityDecision.review => 'review',
      SiteIdentityDecision.escalate => 'escalate',
      SiteIdentityDecision.revoke => 'revoke',
    };
  }

  static SiteIdentityDecision fromCode(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'approve_always' => SiteIdentityDecision.approveAlways,
      'review' => SiteIdentityDecision.review,
      'escalate' => SiteIdentityDecision.escalate,
      'revoke' => SiteIdentityDecision.revoke,
      _ => SiteIdentityDecision.approveOnce,
    };
  }
}

enum SiteIdentityDecisionSource { admin, telegram, aiProposal, system }

extension SiteIdentityDecisionSourceX on SiteIdentityDecisionSource {
  String get code {
    return switch (this) {
      SiteIdentityDecisionSource.admin => 'admin',
      SiteIdentityDecisionSource.telegram => 'telegram',
      SiteIdentityDecisionSource.aiProposal => 'ai_proposal',
      SiteIdentityDecisionSource.system => 'system',
    };
  }

  static SiteIdentityDecisionSource fromCode(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'telegram' => SiteIdentityDecisionSource.telegram,
      'ai_proposal' => SiteIdentityDecisionSource.aiProposal,
      'system' => SiteIdentityDecisionSource.system,
      _ => SiteIdentityDecisionSource.admin,
    };
  }
}

class SiteIdentityProfile {
  final String profileId;
  final String clientId;
  final String siteId;
  final SiteIdentityType identityType;
  final SiteIdentityCategory category;
  final SiteIdentityStatus status;
  final String displayName;
  final String faceMatchId;
  final String plateNumber;
  final String externalReference;
  final String notes;
  final DateTime? validFromUtc;
  final DateTime? validUntilUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Map<String, Object?> metadata;

  const SiteIdentityProfile({
    this.profileId = '',
    required this.clientId,
    required this.siteId,
    required this.identityType,
    required this.category,
    required this.status,
    required this.displayName,
    this.faceMatchId = '',
    this.plateNumber = '',
    this.externalReference = '',
    this.notes = '',
    this.validFromUtc,
    this.validUntilUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.metadata = const <String, Object?>{},
  });

  bool get hasStableIdentity =>
      faceMatchId.trim().isNotEmpty || plateNumber.trim().isNotEmpty;

  SiteIdentityProfile copyWith({
    String? profileId,
    String? clientId,
    String? siteId,
    SiteIdentityType? identityType,
    SiteIdentityCategory? category,
    SiteIdentityStatus? status,
    String? displayName,
    String? faceMatchId,
    String? plateNumber,
    String? externalReference,
    String? notes,
    DateTime? validFromUtc,
    DateTime? validUntilUtc,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    Map<String, Object?>? metadata,
  }) {
    return SiteIdentityProfile(
      profileId: profileId ?? this.profileId,
      clientId: clientId ?? this.clientId,
      siteId: siteId ?? this.siteId,
      identityType: identityType ?? this.identityType,
      category: category ?? this.category,
      status: status ?? this.status,
      displayName: displayName ?? this.displayName,
      faceMatchId: faceMatchId ?? this.faceMatchId,
      plateNumber: plateNumber ?? this.plateNumber,
      externalReference: externalReference ?? this.externalReference,
      notes: notes ?? this.notes,
      validFromUtc: validFromUtc ?? this.validFromUtc,
      validUntilUtc: validUntilUtc ?? this.validUntilUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toUpsertRow() {
    return <String, Object?>{
      if (profileId.trim().isNotEmpty) 'id': profileId.trim(),
      'client_id': clientId.trim(),
      'site_id': siteId.trim(),
      'identity_type': identityType.code,
      'category': category.code,
      'status': status.code,
      'display_name': displayName.trim(),
      'face_match_id': _nullIfBlank(faceMatchId),
      'plate_number': _nullIfBlank(plateNumber),
      'external_reference': _nullIfBlank(externalReference),
      'notes': _nullIfBlank(notes),
      'valid_from': validFromUtc?.toIso8601String(),
      'valid_until': validUntilUtc?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory SiteIdentityProfile.fromRow(Map<String, dynamic> row) {
    DateTime parseDateTime(String key) {
      final parsed = DateTime.tryParse((row[key] ?? '').toString());
      return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
          .toUtc();
    }

    return SiteIdentityProfile(
      profileId: (row['id'] ?? '').toString().trim(),
      clientId: (row['client_id'] ?? '').toString().trim(),
      siteId: (row['site_id'] ?? '').toString().trim(),
      identityType: SiteIdentityTypeX.fromCode(
        (row['identity_type'] ?? '').toString(),
      ),
      category: SiteIdentityCategoryX.fromCode(
        (row['category'] ?? '').toString(),
      ),
      status: SiteIdentityStatusX.fromCode((row['status'] ?? '').toString()),
      displayName: (row['display_name'] ?? '').toString().trim(),
      faceMatchId: (row['face_match_id'] ?? '').toString().trim(),
      plateNumber: (row['plate_number'] ?? '').toString().trim(),
      externalReference: (row['external_reference'] ?? '').toString().trim(),
      notes: (row['notes'] ?? '').toString().trim(),
      validFromUtc: DateTime.tryParse(
        (row['valid_from'] ?? '').toString(),
      )?.toUtc(),
      validUntilUtc: DateTime.tryParse(
        (row['valid_until'] ?? '').toString(),
      )?.toUtc(),
      createdAtUtc: parseDateTime('created_at'),
      updatedAtUtc: parseDateTime('updated_at'),
      metadata: Map<String, Object?>.from(
        (row['metadata'] as Map?) ?? const <String, Object?>{},
      ),
    );
  }
}

class SiteIdentityApprovalDecisionRecord {
  final String decisionId;
  final String clientId;
  final String siteId;
  final String profileId;
  final String intelligenceId;
  final SiteIdentityDecision decision;
  final SiteIdentityDecisionSource source;
  final String decidedBy;
  final String decisionSummary;
  final DateTime decidedAtUtc;
  final Map<String, Object?> metadata;

  const SiteIdentityApprovalDecisionRecord({
    this.decisionId = '',
    required this.clientId,
    required this.siteId,
    this.profileId = '',
    this.intelligenceId = '',
    required this.decision,
    required this.source,
    required this.decidedBy,
    this.decisionSummary = '',
    required this.decidedAtUtc,
    this.metadata = const <String, Object?>{},
  });

  Map<String, Object?> toInsertRow() {
    return <String, Object?>{
      if (decisionId.trim().isNotEmpty) 'id': decisionId.trim(),
      'client_id': clientId.trim(),
      'site_id': siteId.trim(),
      'profile_id': _nullIfBlank(profileId),
      'intelligence_id': _nullIfBlank(intelligenceId),
      'decision': decision.code,
      'source': source.code,
      'decided_by': decidedBy.trim(),
      'decision_summary': _nullIfBlank(decisionSummary),
      'decided_at': decidedAtUtc.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class TelegramIdentityIntakeRecord {
  final String intakeId;
  final String clientId;
  final String siteId;
  final String endpointId;
  final String rawText;
  final String parsedDisplayName;
  final String parsedFaceMatchId;
  final String parsedPlateNumber;
  final SiteIdentityCategory category;
  final DateTime? validFromUtc;
  final DateTime? validUntilUtc;
  final double aiConfidence;
  final String approvalState;
  final DateTime createdAtUtc;
  final Map<String, Object?> metadata;

  const TelegramIdentityIntakeRecord({
    this.intakeId = '',
    required this.clientId,
    required this.siteId,
    this.endpointId = '',
    required this.rawText,
    this.parsedDisplayName = '',
    this.parsedFaceMatchId = '',
    this.parsedPlateNumber = '',
    this.category = SiteIdentityCategory.unknown,
    this.validFromUtc,
    this.validUntilUtc,
    this.aiConfidence = 0,
    this.approvalState = 'pending',
    required this.createdAtUtc,
    this.metadata = const <String, Object?>{},
  });

  Map<String, Object?> toInsertRow() {
    return <String, Object?>{
      if (intakeId.trim().isNotEmpty) 'id': intakeId.trim(),
      'client_id': clientId.trim(),
      'site_id': siteId.trim(),
      'endpoint_id': _nullIfBlank(endpointId),
      'raw_text': rawText.trim(),
      'parsed_display_name': _nullIfBlank(parsedDisplayName),
      'parsed_face_match_id': _nullIfBlank(parsedFaceMatchId),
      'parsed_plate_number': _nullIfBlank(parsedPlateNumber),
      'parsed_category': category.code,
      'valid_from': validFromUtc?.toIso8601String(),
      'valid_until': validUntilUtc?.toIso8601String(),
      'ai_confidence': aiConfidence,
      'approval_state': approvalState.trim().isEmpty
          ? 'pending'
          : approvalState.trim(),
      'created_at': createdAtUtc.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory TelegramIdentityIntakeRecord.fromRow(Map<String, dynamic> row) {
    DateTime parseDateTime(String key) {
      final parsed = DateTime.tryParse((row[key] ?? '').toString());
      return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
          .toUtc();
    }

    return TelegramIdentityIntakeRecord(
      intakeId: (row['id'] ?? '').toString().trim(),
      clientId: (row['client_id'] ?? '').toString().trim(),
      siteId: (row['site_id'] ?? '').toString().trim(),
      endpointId: (row['endpoint_id'] ?? '').toString().trim(),
      rawText: (row['raw_text'] ?? '').toString().trim(),
      parsedDisplayName: (row['parsed_display_name'] ?? '').toString().trim(),
      parsedFaceMatchId: (row['parsed_face_match_id'] ?? '').toString().trim(),
      parsedPlateNumber: (row['parsed_plate_number'] ?? '').toString().trim(),
      category: SiteIdentityCategoryX.fromCode(
        (row['parsed_category'] ?? '').toString(),
      ),
      validFromUtc: DateTime.tryParse(
        (row['valid_from'] ?? '').toString(),
      )?.toUtc(),
      validUntilUtc: DateTime.tryParse(
        (row['valid_until'] ?? '').toString(),
      )?.toUtc(),
      aiConfidence:
          double.tryParse((row['ai_confidence'] ?? '').toString()) ?? 0,
      approvalState: (row['approval_state'] ?? 'pending').toString().trim(),
      createdAtUtc: parseDateTime('created_at'),
      metadata: Map<String, Object?>.from(
        (row['metadata'] as Map?) ?? const <String, Object?>{},
      ),
    );
  }
}

class SupabaseSiteIdentityRegistryRepository {
  final SupabaseClient client;

  const SupabaseSiteIdentityRegistryRepository(this.client);

  Future<List<SiteIdentityProfile>> listProfiles({
    required String clientId,
    required String siteId,
  }) async {
    final rows = await client
        .from('site_identity_profiles')
        .select()
        .eq('client_id', clientId.trim())
        .eq('site_id', siteId.trim())
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(SiteIdentityProfile.fromRow).toList(growable: false);
  }

  Future<void> upsertProfile(SiteIdentityProfile profile) async {
    final row = profile.toUpsertRow();
    if (profile.profileId.trim().isNotEmpty) {
      await client.from('site_identity_profiles').upsert(row, onConflict: 'id');
      return;
    }
    await client.from('site_identity_profiles').insert(row);
  }

  Future<void> insertApprovalDecision(
    SiteIdentityApprovalDecisionRecord decision,
  ) async {
    await client
        .from('site_identity_approval_decisions')
        .insert(decision.toInsertRow());
  }

  Future<void> insertTelegramIntake(TelegramIdentityIntakeRecord intake) async {
    await client.from('telegram_identity_intake').insert(intake.toInsertRow());
  }

  Future<List<TelegramIdentityIntakeRecord>> listPendingTelegramIntakes({
    String? clientId,
    String? siteId,
  }) async {
    dynamic query = client.from('telegram_identity_intake').select();
    if ((clientId ?? '').trim().isNotEmpty) {
      query = query.eq('client_id', clientId!.trim());
    }
    if ((siteId ?? '').trim().isNotEmpty) {
      query = query.eq('site_id', siteId!.trim());
    }
    final rows = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows)
        .map(TelegramIdentityIntakeRecord.fromRow)
        .where((record) {
          final state = record.approvalState.trim().toLowerCase();
          return state == 'pending' || state == 'proposed';
        })
        .toList(growable: false);
  }

  Future<void> updateTelegramIntakeApprovalState({
    required String intakeId,
    required String approvalState,
  }) async {
    await client
        .from('telegram_identity_intake')
        .update(<String, Object?>{'approval_state': approvalState.trim()})
        .eq('id', intakeId.trim());
  }

  Future<List<SiteIdentityProfile>> listActiveTemporaryApprovalProfiles({
    String? clientId,
    String? siteId,
    DateTime? nowUtc,
  }) async {
    dynamic query = client
        .from('site_identity_profiles')
        .select()
        .eq('status', SiteIdentityStatus.allowed.code)
        .not('valid_until', 'is', null);
    if ((clientId ?? '').trim().isNotEmpty) {
      query = query.eq('client_id', clientId!.trim());
    }
    if ((siteId ?? '').trim().isNotEmpty) {
      query = query.eq('site_id', siteId!.trim());
    }
    final rows = await query.order('updated_at', ascending: false);
    final when = (nowUtc ?? DateTime.now()).toUtc();
    return List<Map<String, dynamic>>.from(rows)
        .map(SiteIdentityProfile.fromRow)
        .where((profile) {
          final validUntilUtc = profile.validUntilUtc?.toUtc();
          if (validUntilUtc == null || !validUntilUtc.isAfter(when)) {
            return false;
          }
          final validFromUtc = profile.validFromUtc?.toUtc();
          if (validFromUtc != null && validFromUtc.isAfter(when)) {
            return false;
          }
          return profile.hasStableIdentity;
        })
        .toList(growable: false);
  }
}

Object? _nullIfBlank(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}
