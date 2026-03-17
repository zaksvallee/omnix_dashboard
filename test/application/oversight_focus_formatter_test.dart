import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/oversight_focus_formatter.dart';

void main() {
  group('oversight focus formatter', () {
    test('builds shared focus summary for empty, live, and historical shifts', () {
      expect(
        buildOversightFocusSummary(reportDate: '', currentReportDate: ''),
        'Viewing current live oversight shift.',
      );
      expect(
        buildOversightFocusSummary(
          reportDate: '2026-03-17',
          currentReportDate: '2026-03-17',
        ),
        'Viewing live oversight shift 2026-03-17.',
      );
      expect(
        buildOversightFocusSummary(
          reportDate: '2026-03-16',
          currentReportDate: '2026-03-17',
        ),
        'Viewing command-targeted shift 2026-03-16 instead of live oversight 2026-03-17.',
      );
    });

    test('builds shared focus state for live and historical targets', () {
      expect(
        buildOversightFocusState(reportDate: '', currentReportDate: ''),
        'live_current_shift',
      );
      expect(
        buildOversightFocusState(
          reportDate: '2026-03-17',
          currentReportDate: '2026-03-17',
        ),
        'live_current_shift',
      );
      expect(
        buildOversightFocusState(
          reportDate: '2026-03-16',
          currentReportDate: '2026-03-17',
        ),
        'historical_command_target',
      );
    });
  });
}
