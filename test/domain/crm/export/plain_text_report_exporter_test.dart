import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/crm/export/plain_text_report_exporter.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_audience.dart';
import 'package:omnix_dashboard/domain/crm/reporting/report_sections.dart';

import '../../../fixtures/report_test_bundle.dart';

void main() {
  test('plain text exporter includes scene review summary and highlights', () {
    final export = PlainTextReportExporter.export(
      buildTestReportBundle(
        sceneReview: const SceneReviewSnapshot(
          totalReviews: 2,
          modelReviews: 1,
          metadataFallbackReviews: 1,
          suppressedActions: 1,
          incidentAlerts: 0,
          repeatUpdates: 1,
          escalationCandidates: 1,
          topPosture: 'escalation candidate',
          latestActionTaken:
              '2026-03-14T21:18:00.000Z • Camera 2 • Escalation Candidate • Escalated for urgent review because person activity was detected near the boundary.',
          latestSuppressedPattern:
              '2026-03-14T21:16:00.000Z • Camera 3 • Vehicle remained below escalation threshold.',
          highlights: [
            SceneReviewHighlightSnapshot(
              intelligenceId: 'intel-2',
              detectedAt: '2026-03-14T21:18:00.000Z',
              cameraLabel: 'Camera 2',
              sourceLabel: 'metadata:fallback',
              postureLabel: 'escalation candidate',
              decisionLabel: 'Escalation Candidate',
              decisionSummary:
                  'Escalated for urgent review because person activity was detected near the boundary.',
              summary:
                  'Person visible near the boundary after repeat activity.',
            ),
          ],
        ),
      ),
      audience: ReportAudience.client,
    );

    expect(export.content, contains('CCTV SCENE REVIEW'));
    expect(export.content, contains('Total Reviews: 2'));
    expect(export.content, contains('Incident Alerts: 0'));
    expect(export.content, contains('Repeat Updates: 1'));
    expect(export.content, contains('Escalation Candidates: 1'));
    expect(
      export.content,
      contains(
        'Latest Action Taken: 2026-03-14T21:18:00.000Z • Camera 2 • Escalation Candidate • Escalated for urgent review because person activity was detected near the boundary.',
      ),
    );
    expect(
      export.content,
      contains(
        'Latest Suppressed Pattern: 2026-03-14T21:16:00.000Z • Camera 3 • Vehicle remained below escalation threshold.',
      ),
    );
    expect(
      export.content,
      contains(
        'Camera 2 | escalation candidate | Escalation Candidate | Escalated for urgent review because person activity was detected near the boundary. | Person visible near the boundary after repeat activity.',
      ),
    );
  });
}
