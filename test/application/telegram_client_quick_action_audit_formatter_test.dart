import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/telegram_client_quick_action_audit_formatter.dart';
import 'package:omnix_dashboard/application/telegram_client_quick_action_service.dart';

void main() {
  const formatter = TelegramClientQuickActionAuditFormatter();

  test('full status preview includes site narrative and decision lines', () {
    final preview = formatter.buildPreview(
      action: TelegramClientQuickAction.statusFull,
      responseText:
          '🧾 ONYX STATUS (FULL)\n'
          'MS Vallee Residence | 12:30\n\n'
          'Monitoring: ACTIVE\n'
          'Window: 24h watch (started 18:00)\n'
          'Reviewed activity: 19\n'
          'Latest activity source: Camera 13\n'
          'Latest posture: multi-camera activity under review\n'
          'Current assessment: likely routine distributed field activity\n'
          'Current site narrative: Recent ONYX review saw 3 person signals across Camera 12, Camera 13, and Camera 6. The movement is spread across the property and overlaps with active worker or guard telemetry.\n'
          'Latest review summary: Distributed person movement remains visible.\n'
          'Latest decision: Escalation candidate remains under verification.\n'
          'Open follow-up actions: 1\n'
          'Monitoring availability: available\n'
          'Last reviewed at: 18/03/2026 12:29\n'
          'Local time: 18/03/2026 12:30',
    );

    expect(preview, contains('🧾 ONYX STATUS (FULL)'));
    expect(preview, contains('MS Vallee Residence | 12:30'));
    expect(
      preview,
      contains(
        'Current assessment: likely routine distributed field activity',
      ),
    );
    expect(
      preview,
      contains(
        'Current site narrative: Recent ONYX review saw 3 person signals across Camera 12, Camera 13, and Camera 6.',
      ),
    );
    expect(
      preview,
      contains(
        'Latest decision: Escalation candidate remains under verification.',
      ),
    );
    expect(preview, isNot(contains('Local time: 18/03/2026 12:30')));
  });

  test('concise status preview stays short', () {
    final preview = formatter.buildPreview(
      action: TelegramClientQuickAction.status,
      responseText:
          '🛡️ ONYX STATUS\n'
          'MS Vallee Residence | 12:30\n\n'
          'Monitoring: ACTIVE\n'
          'Window: 24h watch (started 18:00)\n'
          'Reviewed activity: 5\n'
          'Latest activity: Camera 13\n'
          'Latest posture: calm\n'
          'Current assessment: likely routine distributed field activity\n'
          'ONYX is on active observation and will message only if the posture changes materially.',
    );

    expect(preview, contains('🛡️ ONYX STATUS'));
    expect(preview, contains('Latest posture: calm'));
    expect(
      preview,
      contains('Current assessment: likely routine distributed field activity'),
    );
  });
}
