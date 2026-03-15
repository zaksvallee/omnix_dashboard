import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';

void main() {
  group('MonitoringSceneReviewStore', () {
    const store = MonitoringSceneReviewStore();

    test('parses and serializes persisted scene review records', () {
      final restored = store.parsePersistedState({
        'INTEL-1': <String, Object?>{
          'intelligence_id': 'INTEL-1',
        'evidence_record_hash': 'evidence-hash-1',
        'source_label': 'openai:gpt-4.1-mini',
        'posture_label': 'escalation candidate',
        'decision_label': 'Escalation Candidate',
        'decision_summary':
            'Escalated for urgent review because person activity was detected and confidence remained high.',
        'summary': 'Person visible near the boundary line.',
        'reviewed_at_utc': '2026-03-14T21:14:00.000Z',
      },
      });

      expect(restored.keys, ['INTEL-1']);
      expect(restored['INTEL-1']?.sourceLabel, 'openai:gpt-4.1-mini');
      expect(restored['INTEL-1']?.postureLabel, 'escalation candidate');
      expect(restored['INTEL-1']?.decisionLabel, 'Escalation Candidate');
      expect(
        restored['INTEL-1']?.decisionSummary,
        contains('Escalated for urgent review'),
      );
      expect(
        restored['INTEL-1']?.reviewedAtUtc,
        DateTime.utc(2026, 3, 14, 21, 14),
      );

      final prepared = store.preparePersistedState(restored);
      expect(prepared.shouldClear, isFalse);
      expect(
        (prepared.serializedState['INTEL-1'] as Map<String, Object?>)['summary'],
        'Person visible near the boundary line.',
      );
      expect(
        (prepared.serializedState['INTEL-1'] as Map<String, Object?>)['decision_label'],
        'Escalation Candidate',
      );
    });

    test('builds normalized scene review record', () {
      final record = store.buildRecord(
        intelligenceId: ' INTEL-2 ',
        evidenceRecordHash: ' evidence-hash-2 ',
        sourceLabel: ' openai:gpt-4.1-mini ',
        postureLabel: ' monitored movement alert ',
        decisionLabel: ' Monitoring Alert ',
        decisionSummary:
            ' Client alert sent because vehicle activity was detected and confidence remained medium. ',
        summary: ' Vehicle remains visible in the monitored lane. ',
        reviewedAtUtc: DateTime.utc(2026, 3, 14, 21, 20),
      );

      expect(record.intelligenceId, 'INTEL-2');
      expect(record.evidenceRecordHash, 'evidence-hash-2');
      expect(record.sourceLabel, 'openai:gpt-4.1-mini');
      expect(record.postureLabel, 'monitored movement alert');
      expect(record.decisionLabel, 'Monitoring Alert');
      expect(
        record.decisionSummary,
        'Client alert sent because vehicle activity was detected and confidence remained medium.',
      );
      expect(record.summary, 'Vehicle remains visible in the monitored lane.');
    });
  });
}
