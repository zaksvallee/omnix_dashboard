import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/synthetic_promotion_summary_formatter.dart';

void main() {
  group('buildSyntheticPromotionSummary', () {
    test('returns base summary when no urgency context exists', () {
      expect(
        buildSyntheticPromotionSummary(baseSummary: 'Promote MO-1'),
        'Promote MO-1',
      );
    });

    test('adds current and previous urgency context when both exist', () {
      expect(
        buildSyntheticPromotionSummary(
          baseSummary: 'Promote MO-1',
          shadowTomorrowUrgencySummary: 'strength rising • critical • 22s',
          previousShadowTomorrowUrgencySummary:
              'strength stable • high • 28s',
        ),
        'Promote MO-1 • pressure strength rising • critical • 22s (prev strength stable • high • 28s)',
      );
    });
  });

  group('buildSyntheticPromotionDecisionSummary', () {
    test('returns base decision when no urgency context exists', () {
      expect(
        buildSyntheticPromotionDecisionSummary(
          baseSummary: 'Accepted toward validated review.',
        ),
        'Accepted toward validated review.',
      );
    });

    test('adds current and previous urgency context when both exist', () {
      expect(
        buildSyntheticPromotionDecisionSummary(
          baseSummary: 'Accepted toward validated review.',
          shadowTomorrowUrgencySummary: 'strength rising • critical • 22s',
          previousShadowTomorrowUrgencySummary:
              'strength stable • high • 28s',
        ),
        'Accepted toward validated review. • under strength rising • critical • 22s pressure (prev strength stable • high • 28s)',
      );
    });
  });
}
