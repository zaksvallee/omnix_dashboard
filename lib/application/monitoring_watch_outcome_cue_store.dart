class MonitoringWatchOutcomeCueState {
  final String label;
  final DateTime recordedAtUtc;

  const MonitoringWatchOutcomeCueState({
    required this.label,
    required this.recordedAtUtc,
  });
}

class MonitoringWatchOutcomeCueUpdate {
  final Map<String, MonitoringWatchOutcomeCueState> stateByScope;
  final bool changed;

  const MonitoringWatchOutcomeCueUpdate({
    required this.stateByScope,
    required this.changed,
  });
}

class MonitoringWatchOutcomeCueStore {
  static const Duration cueWindow = Duration(minutes: 5);

  const MonitoringWatchOutcomeCueStore();

  bool isExpired({required DateTime recordedAtUtc, required DateTime nowUtc}) {
    return nowUtc.difference(recordedAtUtc.toUtc()) > cueWindow;
  }

  String? labelForState({
    required MonitoringWatchOutcomeCueState? state,
    required DateTime nowUtc,
  }) {
    if (state == null) {
      return null;
    }
    if (isExpired(recordedAtUtc: state.recordedAtUtc, nowUtc: nowUtc)) {
      return null;
    }
    final label = state.label.trim();
    return label.isEmpty ? null : label;
  }

  Map<String, MonitoringWatchOutcomeCueState> freshState({
    required Map<String, MonitoringWatchOutcomeCueState> stateByScope,
    required DateTime nowUtc,
  }) {
    return Map<String, MonitoringWatchOutcomeCueState>.fromEntries(
      stateByScope.entries.where(
        (entry) => !isExpired(
          recordedAtUtc: entry.value.recordedAtUtc,
          nowUtc: nowUtc,
        ),
      ),
    );
  }

  MonitoringWatchOutcomeCueUpdate recordCue({
    required Map<String, MonitoringWatchOutcomeCueState> stateByScope,
    required String scopeKey,
    required String label,
    required DateTime nowUtc,
  }) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return MonitoringWatchOutcomeCueUpdate(
        stateByScope: freshState(stateByScope: stateByScope, nowUtc: nowUtc),
        changed: false,
      );
    }
    final fresh = freshState(stateByScope: stateByScope, nowUtc: nowUtc);
    final next = Map<String, MonitoringWatchOutcomeCueState>.from(fresh)
      ..[scopeKey] = MonitoringWatchOutcomeCueState(
        label: trimmed,
        recordedAtUtc: nowUtc,
      );
    final changed =
        next.length != stateByScope.length ||
        stateByScope[scopeKey]?.label != trimmed ||
        stateByScope[scopeKey]?.recordedAtUtc != nowUtc;
    return MonitoringWatchOutcomeCueUpdate(
      stateByScope: next,
      changed: changed,
    );
  }
}
