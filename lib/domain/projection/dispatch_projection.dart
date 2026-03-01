import '../events/dispatch_event.dart';
import '../events/decision_created.dart';
import '../events/execution_completed.dart';

class DispatchProjection {
  final Map<String, Map<String, Map<String, Map<String, String>>>> _state = {};

  void apply(DispatchEvent event) {
    if (event is DecisionCreated) {
      _state
          .putIfAbsent(event.clientId, () => {})
          .putIfAbsent(event.regionId, () => {})
          .putIfAbsent(event.siteId, () => {})[event.dispatchId] = 'DECIDED';
    }

    if (event is ExecutionCompleted) {
      _state
          .putIfAbsent(event.clientId, () => {})
          .putIfAbsent(event.regionId, () => {})
          .putIfAbsent(event.siteId, () => {})[event.dispatchId] =
          event.success ? 'EXECUTED' : 'FAILED';
    }
  }

  String? statusOf({
    required String clientId,
    required String regionId,
    required String siteId,
    required String dispatchId,
  }) {
    return _state[clientId]?[regionId]?[siteId]?[dispatchId];
  }

  Map<String, Map<String, Map<String, Map<String, String>>>> snapshot() {
    return _state;
  }
}
