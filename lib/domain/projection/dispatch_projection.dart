import '../events/dispatch_event.dart';
import '../events/decision_created.dart';
import '../events/execution_completed.dart';
import '../events/execution_denied.dart';

class DispatchProjection {
  final Map<String, Map<String, Map<String, Map<String, String>>>> _state = {};

  void apply(DispatchEvent event) {
    if (event is DecisionCreated) {
      _write(
        clientId: event.clientId,
        regionId: event.regionId,
        siteId: event.siteId,
        dispatchId: event.dispatchId,
        status: 'DECIDED',
      );
      return;
    }

    if (event is ExecutionCompleted) {
      _write(
        clientId: event.clientId,
        regionId: event.regionId,
        siteId: event.siteId,
        dispatchId: event.dispatchId,
        status: event.success ? 'EXECUTED' : 'FAILED',
      );
      return;
    }

    if (event is ExecutionDenied) {
      _write(
        clientId: event.clientId,
        regionId: event.regionId,
        siteId: event.siteId,
        dispatchId: event.dispatchId,
        status: 'DENIED',
      );
      return;
    }
  }

  void _write({
    required String clientId,
    required String regionId,
    required String siteId,
    required String dispatchId,
    required String status,
  }) {
    _state
        .putIfAbsent(clientId, () => {})
        .putIfAbsent(regionId, () => {})
        .putIfAbsent(siteId, () => {})[dispatchId] = status;
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
    return Map.unmodifiable(_state);
  }

  void rebuildFrom(List<DispatchEvent> events) {
    _state.clear();

    final ordered = List<DispatchEvent>.from(events)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    for (final event in ordered) {
      apply(event);
    }
  }
}
