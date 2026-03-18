class MonitoringWatchRuntimeState {
  final DateTime startedAtUtc;
  final int reviewedEvents;
  final String primaryActivitySource;
  final int dispatchCount;
  final int alertCount;
  final int repeatCount;
  final int escalationCount;
  final int suppressedCount;
  final bool monitoringAvailable;
  final int unresolvedActionCount;
  final String latestSceneReviewSourceLabel;
  final String latestSceneReviewPostureLabel;
  final String latestSceneReviewSummary;
  final String latestSceneDecisionLabel;
  final String latestSceneDecisionSummary;
  final DateTime? latestSceneReviewUpdatedAtUtc;
  final String latestClientDecisionLabel;
  final String latestClientDecisionSummary;
  final DateTime? latestClientDecisionAtUtc;
  final String latestClientNotificationLabel;
  final String latestClientNotificationSummary;
  final DateTime? latestClientNotificationAtUtc;
  final List<String> actionHistory;
  final List<String> suppressedHistory;

  const MonitoringWatchRuntimeState({
    required this.startedAtUtc,
    this.reviewedEvents = 0,
    this.primaryActivitySource = '',
    this.dispatchCount = 0,
    this.alertCount = 0,
    this.repeatCount = 0,
    this.escalationCount = 0,
    this.suppressedCount = 0,
    this.monitoringAvailable = true,
    this.unresolvedActionCount = 0,
    this.latestSceneReviewSourceLabel = '',
    this.latestSceneReviewPostureLabel = '',
    this.latestSceneReviewSummary = '',
    this.latestSceneDecisionLabel = '',
    this.latestSceneDecisionSummary = '',
    this.latestSceneReviewUpdatedAtUtc,
    this.latestClientDecisionLabel = '',
    this.latestClientDecisionSummary = '',
    this.latestClientDecisionAtUtc,
    this.latestClientNotificationLabel = '',
    this.latestClientNotificationSummary = '',
    this.latestClientNotificationAtUtc,
    this.actionHistory = const <String>[],
    this.suppressedHistory = const <String>[],
  });

  MonitoringWatchRuntimeState copyWith({
    DateTime? startedAtUtc,
    int? reviewedEvents,
    String? primaryActivitySource,
    int? dispatchCount,
    int? alertCount,
    int? repeatCount,
    int? escalationCount,
    int? suppressedCount,
    bool? monitoringAvailable,
    int? unresolvedActionCount,
    String? latestSceneReviewSourceLabel,
    String? latestSceneReviewPostureLabel,
    String? latestSceneReviewSummary,
    String? latestSceneDecisionLabel,
    String? latestSceneDecisionSummary,
    DateTime? latestSceneReviewUpdatedAtUtc,
    String? latestClientDecisionLabel,
    String? latestClientDecisionSummary,
    DateTime? latestClientDecisionAtUtc,
    String? latestClientNotificationLabel,
    String? latestClientNotificationSummary,
    DateTime? latestClientNotificationAtUtc,
    List<String>? actionHistory,
    List<String>? suppressedHistory,
  }) {
    return MonitoringWatchRuntimeState(
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      reviewedEvents: reviewedEvents ?? this.reviewedEvents,
      primaryActivitySource:
          primaryActivitySource ?? this.primaryActivitySource,
      dispatchCount: dispatchCount ?? this.dispatchCount,
      alertCount: alertCount ?? this.alertCount,
      repeatCount: repeatCount ?? this.repeatCount,
      escalationCount: escalationCount ?? this.escalationCount,
      suppressedCount: suppressedCount ?? this.suppressedCount,
      monitoringAvailable: monitoringAvailable ?? this.monitoringAvailable,
      unresolvedActionCount:
          unresolvedActionCount ?? this.unresolvedActionCount,
      latestSceneReviewSourceLabel:
          latestSceneReviewSourceLabel ?? this.latestSceneReviewSourceLabel,
      latestSceneReviewPostureLabel:
          latestSceneReviewPostureLabel ?? this.latestSceneReviewPostureLabel,
      latestSceneReviewSummary:
          latestSceneReviewSummary ?? this.latestSceneReviewSummary,
      latestSceneDecisionLabel:
          latestSceneDecisionLabel ?? this.latestSceneDecisionLabel,
      latestSceneDecisionSummary:
          latestSceneDecisionSummary ?? this.latestSceneDecisionSummary,
      latestSceneReviewUpdatedAtUtc:
          latestSceneReviewUpdatedAtUtc ?? this.latestSceneReviewUpdatedAtUtc,
      latestClientDecisionLabel:
          latestClientDecisionLabel ?? this.latestClientDecisionLabel,
      latestClientDecisionSummary:
          latestClientDecisionSummary ?? this.latestClientDecisionSummary,
      latestClientDecisionAtUtc:
          latestClientDecisionAtUtc ?? this.latestClientDecisionAtUtc,
      latestClientNotificationLabel:
          latestClientNotificationLabel ?? this.latestClientNotificationLabel,
      latestClientNotificationSummary:
          latestClientNotificationSummary ??
          this.latestClientNotificationSummary,
      latestClientNotificationAtUtc:
          latestClientNotificationAtUtc ?? this.latestClientNotificationAtUtc,
      actionHistory: actionHistory ?? this.actionHistory,
      suppressedHistory: suppressedHistory ?? this.suppressedHistory,
    );
  }
}

class MonitoringWatchRuntimePersistenceState {
  final Map<String, Object?> serializedState;
  final bool shouldClear;

  const MonitoringWatchRuntimePersistenceState({
    required this.serializedState,
    required this.shouldClear,
  });
}

class MonitoringWatchRuntimeStore {
  static const int maxActionHistoryEntries = 3;
  static const int maxSuppressedHistoryEntries = 3;

  const MonitoringWatchRuntimeStore();

  Map<String, MonitoringWatchRuntimeState> parsePersistedState(
    Map<String, Object?> raw,
  ) {
    final restored = <String, MonitoringWatchRuntimeState>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final map = value.map(
        (key, item) => MapEntry(key.toString(), item as Object?),
      );
      final startedAtRaw = (map['started_at_utc'] ?? '').toString().trim();
      final startedAt = DateTime.tryParse(startedAtRaw)?.toUtc();
      if (startedAt == null) {
        continue;
      }
      restored[entry.key] = MonitoringWatchRuntimeState(
        startedAtUtc: startedAt,
        reviewedEvents: _readInt(map['reviewed_events']),
        primaryActivitySource: (map['primary_activity_source'] ?? '')
            .toString()
            .trim(),
        dispatchCount: _readInt(map['dispatch_count']),
        alertCount: _readInt(map['alert_count']),
        repeatCount: _readInt(map['repeat_count']),
        escalationCount: _readInt(map['escalation_count']),
        suppressedCount: _readInt(map['suppressed_count']),
        monitoringAvailable: map['monitoring_available'] != false,
        unresolvedActionCount: _readInt(map['unresolved_action_count']),
        latestSceneReviewSourceLabel: (map['latest_scene_review_source_label'] ??
                '')
            .toString()
            .trim(),
        latestSceneReviewPostureLabel:
            (map['latest_scene_review_posture_label'] ?? '')
                .toString()
                .trim(),
        latestSceneReviewSummary: (map['latest_scene_review_summary'] ?? '')
            .toString()
            .trim(),
        latestSceneDecisionLabel: (map['latest_scene_decision_label'] ?? '')
            .toString()
            .trim(),
        latestSceneDecisionSummary: (map['latest_scene_decision_summary'] ?? '')
            .toString()
            .trim(),
        latestSceneReviewUpdatedAtUtc: DateTime.tryParse(
          (map['latest_scene_review_updated_at_utc'] ?? '')
              .toString()
              .trim(),
        )?.toUtc(),
        latestClientDecisionLabel: (map['latest_client_decision_label'] ?? '')
            .toString()
            .trim(),
        latestClientDecisionSummary:
            (map['latest_client_decision_summary'] ?? '')
                .toString()
                .trim(),
        latestClientDecisionAtUtc: DateTime.tryParse(
          (map['latest_client_decision_at_utc'] ?? '').toString().trim(),
        )?.toUtc(),
        latestClientNotificationLabel:
            (map['latest_client_notification_label'] ?? '').toString().trim(),
        latestClientNotificationSummary:
            (map['latest_client_notification_summary'] ?? '')
                .toString()
                .trim(),
        latestClientNotificationAtUtc: DateTime.tryParse(
          (map['latest_client_notification_at_utc'] ?? '').toString().trim(),
        )?.toUtc(),
        actionHistory: ((map['action_history'] as List?) ?? const [])
            .map((entry) => entry?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty)
            .take(maxActionHistoryEntries)
            .toList(growable: false),
        suppressedHistory: ((map['suppressed_history'] as List?) ?? const [])
            .map((entry) => entry?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty)
            .take(maxSuppressedHistoryEntries)
            .toList(growable: false),
      );
    }
    return restored;
  }

  MonitoringWatchRuntimePersistenceState preparePersistedState(
    Map<String, MonitoringWatchRuntimeState> stateByScope,
  ) {
    final serialized = serializeState(stateByScope);
    return MonitoringWatchRuntimePersistenceState(
      serializedState: serialized,
      shouldClear: serialized.isEmpty,
    );
  }

  MonitoringWatchRuntimeState applyReviewedActivity({
    required MonitoringWatchRuntimeState runtime,
    required int reviewedEventDelta,
    required String activitySource,
    int alertDelta = 0,
    int repeatDelta = 0,
    int escalationDelta = 0,
    int suppressedDelta = 0,
    String sceneReviewSourceLabel = '',
    String sceneReviewPostureLabel = '',
    String sceneReviewSummary = '',
    String sceneDecisionLabel = '',
    String sceneDecisionSummary = '',
    DateTime? sceneReviewRecordedAtUtc,
  }) {
    final normalizedSource = activitySource.trim();
    final normalizedReviewSource = sceneReviewSourceLabel.trim();
    final normalizedReviewPosture = sceneReviewPostureLabel.trim();
    final normalizedReviewSummary = sceneReviewSummary.trim();
    final normalizedDecisionLabel = sceneDecisionLabel.trim();
    final normalizedDecisionSummary = sceneDecisionSummary.trim();
    final actionHistoryEntry = _buildActionHistoryEntry(
      activitySource: normalizedSource,
      decisionLabel: normalizedDecisionLabel,
      decisionSummary: normalizedDecisionSummary,
      alertDelta: alertDelta,
      repeatDelta: repeatDelta,
      escalationDelta: escalationDelta,
      recordedAtUtc: sceneReviewRecordedAtUtc,
    );
    final suppressedHistoryEntry = suppressedDelta <= 0
        ? null
        : _buildSuppressedHistoryEntry(
            activitySource: normalizedSource,
            decisionSummary: normalizedDecisionSummary,
            reviewSummary: normalizedReviewSummary,
            recordedAtUtc: sceneReviewRecordedAtUtc,
          );
    return runtime.copyWith(
      reviewedEvents: runtime.reviewedEvents + reviewedEventDelta,
      primaryActivitySource: runtime.primaryActivitySource.trim().isEmpty
          ? normalizedSource
          : runtime.primaryActivitySource,
      alertCount: runtime.alertCount + alertDelta,
      repeatCount: runtime.repeatCount + repeatDelta,
      escalationCount: runtime.escalationCount + escalationDelta,
      suppressedCount: runtime.suppressedCount + suppressedDelta,
      latestSceneReviewSourceLabel: normalizedReviewSource.isEmpty
          ? runtime.latestSceneReviewSourceLabel
          : normalizedReviewSource,
      latestSceneReviewPostureLabel: normalizedReviewPosture.isEmpty
          ? runtime.latestSceneReviewPostureLabel
          : normalizedReviewPosture,
      latestSceneReviewSummary: normalizedReviewSummary.isEmpty
          ? runtime.latestSceneReviewSummary
          : normalizedReviewSummary,
      latestSceneDecisionLabel: normalizedDecisionLabel.isEmpty
          ? runtime.latestSceneDecisionLabel
          : normalizedDecisionLabel,
      latestSceneDecisionSummary: normalizedDecisionSummary.isEmpty
          ? runtime.latestSceneDecisionSummary
          : normalizedDecisionSummary,
      latestSceneReviewUpdatedAtUtc:
          sceneReviewRecordedAtUtc ?? runtime.latestSceneReviewUpdatedAtUtc,
      actionHistory: actionHistoryEntry == null
          ? runtime.actionHistory
          : <String>[
              actionHistoryEntry,
              ...runtime.actionHistory.where(
                (entry) => entry.trim() != actionHistoryEntry,
              ),
            ].take(maxActionHistoryEntries).toList(growable: false),
      suppressedHistory: suppressedHistoryEntry == null
          ? runtime.suppressedHistory
          : <String>[
              suppressedHistoryEntry,
              ...runtime.suppressedHistory.where(
                (entry) => entry.trim() != suppressedHistoryEntry,
              ),
            ].take(maxSuppressedHistoryEntries).toList(growable: false),
    );
  }

  MonitoringWatchRuntimeState applyClientDecision({
    required MonitoringWatchRuntimeState runtime,
    required String decisionLabel,
    required String decisionSummary,
    required DateTime decidedAtUtc,
  }) {
    final normalizedLabel = decisionLabel.trim();
    final normalizedSummary = decisionSummary.trim();
    return runtime.copyWith(
      latestClientDecisionLabel: normalizedLabel,
      latestClientDecisionSummary: normalizedSummary,
      latestClientDecisionAtUtc: decidedAtUtc.toUtc(),
    );
  }

  MonitoringWatchRuntimeState applyClientNotification({
    required MonitoringWatchRuntimeState runtime,
    required String notificationLabel,
    required String notificationSummary,
    required DateTime notifiedAtUtc,
  }) {
    final normalizedLabel = notificationLabel.trim();
    final normalizedSummary = notificationSummary.trim();
    return runtime.copyWith(
      latestClientNotificationLabel: normalizedLabel,
      latestClientNotificationSummary: normalizedSummary,
      latestClientNotificationAtUtc: notifiedAtUtc.toUtc(),
    );
  }

  Map<String, Object?> serializeState(
    Map<String, MonitoringWatchRuntimeState> stateByScope,
  ) {
    final output = <String, Object?>{};
    for (final entry in stateByScope.entries) {
      final runtime = entry.value;
      output[entry.key] = <String, Object?>{
        'started_at_utc': runtime.startedAtUtc.toIso8601String(),
        'reviewed_events': runtime.reviewedEvents,
        'primary_activity_source': runtime.primaryActivitySource,
        'dispatch_count': runtime.dispatchCount,
        'alert_count': runtime.alertCount,
        'repeat_count': runtime.repeatCount,
        'escalation_count': runtime.escalationCount,
        'suppressed_count': runtime.suppressedCount,
        'monitoring_available': runtime.monitoringAvailable,
        'unresolved_action_count': runtime.unresolvedActionCount,
        'latest_scene_review_source_label': runtime.latestSceneReviewSourceLabel,
        'latest_scene_review_posture_label':
            runtime.latestSceneReviewPostureLabel,
        'latest_scene_review_summary': runtime.latestSceneReviewSummary,
        'latest_scene_decision_label': runtime.latestSceneDecisionLabel,
        'latest_scene_decision_summary': runtime.latestSceneDecisionSummary,
        'latest_scene_review_updated_at_utc': runtime
            .latestSceneReviewUpdatedAtUtc
            ?.toIso8601String(),
        'latest_client_decision_label': runtime.latestClientDecisionLabel,
        'latest_client_decision_summary': runtime.latestClientDecisionSummary,
        'latest_client_decision_at_utc': runtime.latestClientDecisionAtUtc
            ?.toIso8601String(),
        'latest_client_notification_label':
            runtime.latestClientNotificationLabel,
        'latest_client_notification_summary':
            runtime.latestClientNotificationSummary,
        'latest_client_notification_at_utc': runtime
            .latestClientNotificationAtUtc
            ?.toIso8601String(),
        'action_history': runtime.actionHistory,
        'suppressed_history': runtime.suppressedHistory,
      };
    }
    return output;
  }

  String _buildSuppressedHistoryEntry({
    required String activitySource,
    required String decisionSummary,
    required String reviewSummary,
    required DateTime? recordedAtUtc,
  }) {
    final parts = <String>[];
    if (recordedAtUtc != null) {
      final utc = recordedAtUtc.toUtc();
      parts.add(
        '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')} UTC',
      );
    }
    if (activitySource.trim().isNotEmpty) {
      parts.add(activitySource.trim());
    }
    if (decisionSummary.trim().isNotEmpty) {
      parts.add(decisionSummary.trim());
    } else if (reviewSummary.trim().isNotEmpty) {
      parts.add(reviewSummary.trim());
    } else {
      parts.add('Activity remained below threshold.');
    }
    return parts.join(' • ');
  }

  String? _buildActionHistoryEntry({
    required String activitySource,
    required String decisionLabel,
    required String decisionSummary,
    required int alertDelta,
    required int repeatDelta,
    required int escalationDelta,
    required DateTime? recordedAtUtc,
  }) {
    if (alertDelta <= 0 && repeatDelta <= 0 && escalationDelta <= 0) {
      return null;
    }
    final parts = <String>[];
    if (recordedAtUtc != null) {
      final utc = recordedAtUtc.toUtc();
      parts.add(
        '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')} UTC',
      );
    }
    if (activitySource.trim().isNotEmpty) {
      parts.add(activitySource.trim());
    }
    final normalizedDecisionLabel = decisionLabel.trim().isNotEmpty
        ? decisionLabel.trim()
        : _fallbackActionLabel(
            alertDelta: alertDelta,
            repeatDelta: repeatDelta,
            escalationDelta: escalationDelta,
          );
    if (normalizedDecisionLabel.isNotEmpty) {
      parts.add(normalizedDecisionLabel);
    }
    final normalizedDecisionSummary = decisionSummary.trim().isNotEmpty
        ? decisionSummary.trim()
        : _fallbackActionSummary(
            alertDelta: alertDelta,
            repeatDelta: repeatDelta,
            escalationDelta: escalationDelta,
          );
    if (normalizedDecisionSummary.isNotEmpty) {
      parts.add(normalizedDecisionSummary);
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' • ');
  }

  String _fallbackActionLabel({
    required int alertDelta,
    required int repeatDelta,
    required int escalationDelta,
  }) {
    if (repeatDelta > 0) {
      return 'Repeat Activity';
    }
    if (alertDelta > 0) {
      return 'Monitoring Alert';
    }
    if (escalationDelta > 0) {
      return 'Escalation Candidate';
    }
    return '';
  }

  String _fallbackActionSummary({
    required int alertDelta,
    required int repeatDelta,
    required int escalationDelta,
  }) {
    if (repeatDelta > 0) {
      return 'Repeat activity update issued from watch review.';
    }
    if (alertDelta > 0) {
      return 'Client alert issued from watch review.';
    }
    if (escalationDelta > 0) {
      return 'Escalated for urgent watch review.';
    }
    return '';
  }

  int _readInt(Object? candidate) {
    return switch (candidate) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
  }
}
