import '../aggregate/dispatch_aggregate.dart';
import '../events/dispatch_event.dart';
import '../events/decision_created.dart';
import '../events/execution_completed.dart';

class ReplayConsistencyVerifier {
  static void verify(List<DispatchEvent> events) {
    final first = DispatchAggregate.rebuild(events);
    final second = DispatchAggregate.rebuild(events);

    final firstState = _extractState(first, events);
    final secondState = _extractState(second, events);

    if (!_mapsEqual(firstState, secondState)) {
      throw StateError('Replay consistency verification failed.');
    }
  }

  static Map<String, String?> _extractState(
    DispatchAggregate aggregate,
    List<DispatchEvent> events,
  ) {
    final result = <String, String?>{};

    for (final event in events) {
      if (event is DecisionCreated) {
        result[event.dispatchId] =
            aggregate.statusOf(event.dispatchId);
      }

      if (event is ExecutionCompleted) {
        result[event.dispatchId] =
            aggregate.statusOf(event.dispatchId);
      }
    }

    return result;
  }

  static bool _mapsEqual(
    Map<String, String?> a,
    Map<String, String?> b,
  ) {
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }

    return true;
  }
}
