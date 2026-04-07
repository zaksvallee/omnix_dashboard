import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/crm/crm_event.dart';
import 'package:omnix_dashboard/domain/crm/sla_tier.dart';
import 'package:omnix_dashboard/domain/crm/sla_tier_projection.dart';

CRMEvent _tierAssigned(
  String eventId,
  String clientId,
  String tierName,
) {
  return CRMEvent(
    eventId: eventId,
    aggregateId: clientId,
    type: CRMEventType.slaTierAssigned,
    timestamp: '2026-04-07T08:00:00Z',
    payload: <String, dynamic>{'tier': tierName},
  );
}

void main() {
  group('SLATierProjection.rebuild', () {
    test('returns null when no events are present', () {
      expect(
        SLATierProjection.rebuild(
          clientId: 'CLIENT-1',
          events: const <CRMEvent>[],
        ),
        isNull,
      );
    });

    test('ignores SLA tier assignments for other clients', () {
      final result = SLATierProjection.rebuild(
        clientId: 'CLIENT-1',
        events: <CRMEvent>[
          _tierAssigned('event-1', 'CLIENT-2', 'protect'),
        ],
      );

      expect(result, isNull);
    });

    test('returns the latest valid tier assigned to the client', () {
      final result = SLATierProjection.rebuild(
        clientId: 'CLIENT-1',
        events: <CRMEvent>[
          _tierAssigned('event-1', 'CLIENT-1', 'core'),
          _tierAssigned('event-2', 'CLIENT-1', 'protect'),
          _tierAssigned('event-3', 'CLIENT-1', 'sovereign'),
        ],
      );

      expect(result, SLATier.sovereign);
    });

    test('returns null instead of throwing for an unknown tier name', () {
      final result = SLATierProjection.rebuild(
        clientId: 'CLIENT-1',
        events: <CRMEvent>[
          _tierAssigned('event-1', 'CLIENT-1', 'legacy'),
        ],
      );

      expect(result, isNull);
    });
  });
}
