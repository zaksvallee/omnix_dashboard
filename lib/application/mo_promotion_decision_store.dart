enum MoPromotionDecisionStatus { pending, accepted, rejected }

class MoPromotionDecisionRecord {
  final String moId;
  final String targetValidationStatus;
  final MoPromotionDecisionStatus status;
  final DateTime decidedAtUtc;

  const MoPromotionDecisionRecord({
    required this.moId,
    required this.targetValidationStatus,
    required this.status,
    required this.decidedAtUtc,
  });
}

class MoPromotionDecisionStore {
  const MoPromotionDecisionStore();

  static final Map<String, MoPromotionDecisionRecord> _records =
      <String, MoPromotionDecisionRecord>{};

  MoPromotionDecisionRecord? decisionFor(String moId) {
    return _records[moId.trim()];
  }

  String decisionStatusFor(String moId) {
    final record = decisionFor(moId);
    if (record == null) {
      return 'pending';
    }
    return record.status.name;
  }

  String decisionSummaryFor({
    required String moId,
    required String targetValidationStatus,
  }) {
    final record = decisionFor(moId);
    final normalizedTarget = targetValidationStatus.trim();
    if (record == null) {
      if (normalizedTarget.isEmpty) {
        return '';
      }
      return 'Pending operator decision for $normalizedTarget review.';
    }
    final target = record.targetValidationStatus.trim().isEmpty
        ? normalizedTarget
        : record.targetValidationStatus.trim();
    return switch (record.status) {
      MoPromotionDecisionStatus.pending =>
        target.isEmpty ? '' : 'Pending operator decision for $target review.',
      MoPromotionDecisionStatus.accepted =>
        target.isEmpty ? 'Accepted for promotion review.' : 'Accepted toward $target review.',
      MoPromotionDecisionStatus.rejected =>
        target.isEmpty ? 'Rejected for promotion review.' : 'Rejected for $target review for now.',
    };
  }

  void accept({
    required String moId,
    required String targetValidationStatus,
  }) {
    _records[moId.trim()] = MoPromotionDecisionRecord(
      moId: moId.trim(),
      targetValidationStatus: targetValidationStatus.trim(),
      status: MoPromotionDecisionStatus.accepted,
      decidedAtUtc: DateTime.now().toUtc(),
    );
  }

  void reject({
    required String moId,
    required String targetValidationStatus,
  }) {
    _records[moId.trim()] = MoPromotionDecisionRecord(
      moId: moId.trim(),
      targetValidationStatus: targetValidationStatus.trim(),
      status: MoPromotionDecisionStatus.rejected,
      decidedAtUtc: DateTime.now().toUtc(),
    );
  }

  void reset() {
    _records.clear();
  }
}
