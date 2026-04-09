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
          'Current status\n'
          'Monitoring is active.\n'
          'Watch window: 24h watch (started 18:00)\n'
          'Remote watch: available\n\n'
          'What we see now\n'
          'Items reviewed: 19\n'
          'Latest signal: Camera 13\n'
          'Current posture: multi-camera activity under review\n'
          'Assessment: likely routine on-site team activity\n'
          'Summary: Recent camera review saw 3 person signals across Camera 12, Camera 13, and Camera 6. This overlaps with on-site team activity across Front Yard and Back Yard, so it looks routine.\n'
          'Review note: Distributed person movement remains visible.\n'
          'Last check: 18/03/2026 12:29\n'
          '\n'
          'Next\n'
          'Open follow-ups: 1\n'
          'Current decision: Escalation candidate remains under verification.\n'
          'Next step: ONYX is tracking the open follow-up actions and will send the next confirmed change.\n'
          'Local time: 18/03/2026 12:30',
    );

    expect(preview, contains('🧾 ONYX STATUS (FULL)'));
    expect(preview, contains('MS Vallee Residence | 12:30'));
    expect(
      preview,
      contains('Assessment: likely routine on-site team activity'),
    );
    expect(
      preview,
      contains(
        'Summary: Recent camera review saw 3 person signals across Camera 12, Camera 13, and Camera 6.',
      ),
    );
    expect(
      preview,
      contains(
        'Current decision: Escalation candidate remains under verification.',
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
          'Current status\n'
          'Monitoring is active.\n'
          'Watch window: 24h watch (started 18:00)\n'
          '\n'
          'What we see now\n'
          'Items reviewed: 5\n'
          'Latest signal: Camera 13\n'
          'Current posture: calm\n'
          'Assessment: likely routine on-site team activity\n'
          '\n'
          'Next\n'
          'ONYX stays on watch and will message only if the position changes materially.',
    );

    expect(preview, contains('🛡️ ONYX STATUS'));
    expect(preview, contains('Current posture: calm'));
    expect(
      preview,
      contains('Assessment: likely routine on-site team activity'),
    );
  });

  test('clear action maps to alerts cleared audit label', () {
    final preview = formatter.buildPreview(
      action: TelegramClientQuickAction.clear,
      responseText: 'Alerts cleared. Monitoring continues.',
    );

    expect(preview, 'alerts_cleared');
  });
}
