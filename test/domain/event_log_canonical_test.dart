import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/log/event_log.dart' as legacy_log;
import 'package:omnix_dashboard/domain/logging/event_log.dart'
    as canonical_log;

void main() {
  test('legacy and canonical EventLog paths resolve with compatible accessors', () {
    final legacy = legacy_log.EventLog();
    final canonical = canonical_log.EventLog();
    final event = DecisionCreated(
      eventId: 'EVT-1',
      sequence: 1,
      version: 1,
      occurredAt: DateTime.utc(2026, 3, 13, 0, 0, 0),
      dispatchId: 'DSP-1',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GP',
      siteId: 'SITE-SANDTON',
    );

    legacy.append(event);
    canonical.append(event);

    expect(legacy.events.length, 1);
    expect(canonical.events.length, 1);
    expect(canonical.all().length, 1);
    expect(canonical.all().first.eventId, 'EVT-1');
    expect(legacy.events.first.eventId, 'EVT-1');
  });
}
