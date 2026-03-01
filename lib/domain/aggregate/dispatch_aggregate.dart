import '../events/dispatch_event.dart';
import '../events/decision_created.dart';
import '../events/execution_completed.dart';

class DispatchAggregate {
  final Map<String, String> _status = {};

  DispatchAggregate._();

  static DispatchAggregate rebuild(List<DispatchEvent> events) {
    final aggregate = DispatchAggregate._();

    final sorted = [...events]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    for (final event in sorted) {
      aggregate._apply(event);
    }

    return aggregate;
  }

  void _apply(DispatchEvent event) {
    if (event is DecisionCreated) {
      _status[event.dispatchId] = 'DECIDED';
    }

    if (event is ExecutionCompleted) {
      _status[event.dispatchId] =
          event.success ? 'EXECUTED' : 'FAILED';
    }
  }

  String? statusOf(String dispatchId) => _status[dispatchId];
}
