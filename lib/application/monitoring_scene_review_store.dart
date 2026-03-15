class MonitoringSceneReviewRecord {
  final String intelligenceId;
  final String evidenceRecordHash;
  final String sourceLabel;
  final String postureLabel;
  final String decisionLabel;
  final String decisionSummary;
  final String summary;
  final DateTime reviewedAtUtc;

  const MonitoringSceneReviewRecord({
    required this.intelligenceId,
    this.evidenceRecordHash = '',
    required this.sourceLabel,
    required this.postureLabel,
    this.decisionLabel = '',
    this.decisionSummary = '',
    required this.summary,
    required this.reviewedAtUtc,
  });
}

class MonitoringSceneReviewPersistenceState {
  final Map<String, Object?> serializedState;
  final bool shouldClear;

  const MonitoringSceneReviewPersistenceState({
    required this.serializedState,
    required this.shouldClear,
  });
}

class MonitoringSceneReviewStore {
  const MonitoringSceneReviewStore();

  Map<String, MonitoringSceneReviewRecord> parsePersistedState(
    Map<String, Object?> raw,
  ) {
    final restored = <String, MonitoringSceneReviewRecord>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final map = value.map(
        (key, item) => MapEntry(key.toString(), item as Object?),
      );
      final intelligenceId = (map['intelligence_id'] ?? entry.key)
          .toString()
          .trim();
      final sourceLabel = (map['source_label'] ?? '').toString().trim();
      final postureLabel = (map['posture_label'] ?? '').toString().trim();
      final decisionLabel = (map['decision_label'] ?? '').toString().trim();
      final decisionSummary = (map['decision_summary'] ?? '').toString().trim();
      final summary = (map['summary'] ?? '').toString().trim();
      final reviewedAt = DateTime.tryParse(
        (map['reviewed_at_utc'] ?? '').toString().trim(),
      )?.toUtc();
      if (intelligenceId.isEmpty ||
          sourceLabel.isEmpty ||
          postureLabel.isEmpty ||
          summary.isEmpty ||
          reviewedAt == null) {
        continue;
      }
      restored[intelligenceId] = MonitoringSceneReviewRecord(
        intelligenceId: intelligenceId,
        evidenceRecordHash: (map['evidence_record_hash'] ?? '')
            .toString()
            .trim(),
        sourceLabel: sourceLabel,
        postureLabel: postureLabel,
        decisionLabel: decisionLabel,
        decisionSummary: decisionSummary,
        summary: summary,
        reviewedAtUtc: reviewedAt,
      );
    }
    return restored;
  }

  MonitoringSceneReviewPersistenceState preparePersistedState(
    Map<String, MonitoringSceneReviewRecord> stateByIntelligenceId,
  ) {
    final serialized = serializeState(stateByIntelligenceId);
    return MonitoringSceneReviewPersistenceState(
      serializedState: serialized,
      shouldClear: serialized.isEmpty,
    );
  }

  MonitoringSceneReviewRecord buildRecord({
    required String intelligenceId,
    String evidenceRecordHash = '',
    required String sourceLabel,
    required String postureLabel,
    String decisionLabel = '',
    String decisionSummary = '',
    required String summary,
    required DateTime reviewedAtUtc,
  }) {
    return MonitoringSceneReviewRecord(
      intelligenceId: intelligenceId.trim(),
      evidenceRecordHash: evidenceRecordHash.trim(),
      sourceLabel: sourceLabel.trim(),
      postureLabel: postureLabel.trim(),
      decisionLabel: decisionLabel.trim(),
      decisionSummary: decisionSummary.trim(),
      summary: summary.trim(),
      reviewedAtUtc: reviewedAtUtc.toUtc(),
    );
  }

  Map<String, Object?> serializeState(
    Map<String, MonitoringSceneReviewRecord> stateByIntelligenceId,
  ) {
    final output = <String, Object?>{};
    for (final entry in stateByIntelligenceId.entries) {
      final record = entry.value;
      if (record.intelligenceId.trim().isEmpty ||
          record.sourceLabel.trim().isEmpty ||
          record.postureLabel.trim().isEmpty ||
          record.summary.trim().isEmpty) {
        continue;
      }
      output[entry.key] = <String, Object?>{
        'intelligence_id': record.intelligenceId,
        'evidence_record_hash': record.evidenceRecordHash,
        'source_label': record.sourceLabel,
        'posture_label': record.postureLabel,
        if (record.decisionLabel.trim().isNotEmpty)
          'decision_label': record.decisionLabel,
        if (record.decisionSummary.trim().isNotEmpty)
          'decision_summary': record.decisionSummary,
        'summary': record.summary,
        'reviewed_at_utc': record.reviewedAtUtc.toIso8601String(),
      };
    }
    return output;
  }
}
