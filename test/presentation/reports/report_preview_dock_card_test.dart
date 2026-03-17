import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/presentation/reports/report_preview_dock_card.dart';
import 'package:omnix_dashboard/presentation/reports/report_scene_review_narrative_box.dart';

void main() {
  testWidgets('report preview dock card renders shared shell content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportPreviewDockCard(
            eventId: 'RPT-123',
            detail: 'MS Vallee Residence • Mar 2026',
            statusPills: const [
              Chip(label: Text('Replay Verified')),
              Chip(label: Text('Scene 2')),
            ],
            primaryAction: ElevatedButton(
              onPressed: () {},
              child: const Text('Open Full Preview'),
            ),
            secondaryAction: OutlinedButton(
              onPressed: () {},
              child: const Text('Clear Dock Target'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Preview Dock'), findsOneWidget);
    expect(find.text('RPT-123'), findsOneWidget);
    expect(find.text('MS Vallee Residence • Mar 2026'), findsOneWidget);
    expect(find.text('Replay Verified'), findsOneWidget);
    expect(find.text('Open Full Preview'), findsOneWidget);
  });

  testWidgets('report preview dock card shows entry context when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportPreviewDockCard(
            eventId: 'RPT-CTX-DOCK-1',
            detail: 'MS Vallee Residence • Mar 2026',
            title: 'Governance Preview Dock',
            subtitle:
                'Governance handoff preview target held in the report workspace.',
            contextTitle: 'OPENED FROM GOVERNANCE BRANDING DRIFT',
            contextDetail:
                'This receipt scope was opened from Governance so operators can inspect the generated-report history behind a branding-drift shift.',
            statusPills: const [Chip(label: Text('Replay Verified'))],
            primaryAction: ElevatedButton(
              onPressed: () {},
              child: const Text('Open Full Preview'),
            ),
            secondaryAction: OutlinedButton(
              onPressed: () {},
              child: const Text('Clear Dock Target'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('report-preview-dock-context-banner')),
      findsOneWidget,
    );
    expect(find.text('Governance Preview Dock'), findsOneWidget);
    expect(
      find.textContaining('Governance handoff preview target'),
      findsOneWidget,
    );
    expect(find.text('OPENED FROM GOVERNANCE BRANDING DRIFT'), findsOneWidget);
    expect(
      find.textContaining(
        'This receipt scope was opened from Governance so operators can inspect the generated-report history behind a branding-drift shift.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('report preview dock card trims copy and falls back when blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ReportPreviewDockCard(
                eventId: '  RPT-456  ',
                detail: '  Generated UTC 14 Mar 2026  ',
                statusPills: const [],
                primaryAction: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Open Full Preview'),
                ),
                secondaryAction: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Clear Dock Target'),
                ),
              ),
              ReportPreviewDockCard(
                eventId: '   ',
                detail: '   ',
                statusPills: const [],
                primaryAction: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Open Full Preview'),
                ),
                secondaryAction: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Clear Dock Target'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('RPT-456'), findsOneWidget);
    expect(find.text('Generated UTC 14 Mar 2026'), findsOneWidget);
    expect(find.text('Pending target'), findsOneWidget);
    expect(find.text('Awaiting receipt detail.'), findsOneWidget);
  });

  testWidgets('scene review narrative box renders provided narrative', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportSceneReviewNarrativeBox(
            narrative: 'Scene review flagged 1 escalation candidate.',
            accent: Color(0xFFFF7A7A),
          ),
        ),
      ),
    );

    expect(
      find.text('Scene review flagged 1 escalation candidate.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'scene review narrative box trims narrative and falls back when blank',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ReportSceneReviewNarrativeBox(
                  narrative:
                      '  Reviewed vehicle movement remained below threshold.  ',
                  accent: Color(0xFFF6C067),
                ),
                ReportSceneReviewNarrativeBox(
                  narrative: '   ',
                  accent: Color(0xFFF6C067),
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.text('Reviewed vehicle movement remained below threshold.'),
        findsOneWidget,
      );
      expect(find.text('Scene review detail pending.'), findsOneWidget);
    },
  );
}
