import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/aggregate/dispatch_aggregate.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/execution_completed.dart';

DateTime _occurredAt(int sequence) => DateTime.utc(2026, 4, 7, 8, sequence);

DecisionCreated _decision(String dispatchId, int sequence) {
  return DecisionCreated(
    eventId: 'decision-$dispatchId-$sequence',
    sequence: sequence,
    version: 1,
    occurredAt: _occurredAt(sequence),
    dispatchId: dispatchId,
    clientId: 'CLIENT-1',
    regionId: 'REGION-1',
    siteId: 'SITE-1',
  );
}

ExecutionCompleted _execution(
  String dispatchId,
  int sequence, {
  required bool success,
}) {
  return ExecutionCompleted(
    eventId: 'execution-$dispatchId-$sequence',
    sequence: sequence,
    version: 1,
    occurredAt: _occurredAt(sequence),
    dispatchId: dispatchId,
    clientId: 'CLIENT-1',
    regionId: 'REGION-1',
    siteId: 'SITE-1',
    success: success,
  );
}

void main() {
  group('DispatchAggregate.rebuild', () {
    test('returns null for unknown dispatches when event list is empty', () {
      final aggregate = DispatchAggregate.rebuild(const <DispatchEvent>[]);

      expect(aggregate.statusOf('DISPATCH-1'), isNull);
    });

    test('DecisionCreated sets dispatch status to DECIDED', () {
      final aggregate = DispatchAggregate.rebuild(<DispatchEvent>[
        _decision('DISPATCH-1', 1),
      ]);

      expect(aggregate.statusOf('DISPATCH-1'), 'DECIDED');
    });

    test('ExecutionCompleted maps success and failure outcomes', () {
      final aggregate = DispatchAggregate.rebuild(<DispatchEvent>[
        _decision('DISPATCH-1', 1),
        _execution('DISPATCH-1', 2, success: true),
        _decision('DISPATCH-2', 3),
        _execution('DISPATCH-2', 4, success: false),
      ]);

      expect(aggregate.statusOf('DISPATCH-1'), 'CONFIRMED');
      expect(aggregate.statusOf('DISPATCH-2'), 'FAILED');
    });

    test('sorts out-of-order events by sequence before applying', () {
      final aggregate = DispatchAggregate.rebuild(<DispatchEvent>[
        _execution('DISPATCH-1', 2, success: true),
        _decision('DISPATCH-1', 1),
      ]);

      expect(aggregate.statusOf('DISPATCH-1'), 'CONFIRMED');
    });

    test('tracks multiple dispatches independently', () {
      final aggregate = DispatchAggregate.rebuild(<DispatchEvent>[
        _decision('DISPATCH-1', 1),
        _decision('DISPATCH-2', 2),
        _execution('DISPATCH-1', 3, success: false),
      ]);

      expect(aggregate.statusOf('DISPATCH-1'), 'FAILED');
      expect(aggregate.statusOf('DISPATCH-2'), 'DECIDED');
      expect(aggregate.statusOf('DISPATCH-UNKNOWN'), isNull);
    });
  });
}
