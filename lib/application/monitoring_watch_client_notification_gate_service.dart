import 'monitoring_watch_escalation_policy_service.dart';
import 'monitoring_watch_runtime_store.dart';

class MonitoringWatchClientNotificationGateDecision {
  final bool shouldNotifyClient;
  final String summary;

  const MonitoringWatchClientNotificationGateDecision({
    required this.shouldNotifyClient,
    required this.summary,
  });
}

class MonitoringWatchClientNotificationGateService {
  static const Duration minimumNotificationGap = Duration(minutes: 3);
  static const Duration repeatLabelCooldown = Duration(minutes: 10);

  const MonitoringWatchClientNotificationGateService();

  MonitoringWatchClientNotificationGateDecision decide({
    required MonitoringWatchRuntimeState runtime,
    required MonitoringWatchEscalationDecision decision,
    required DateTime occurredAtUtc,
    bool monitoringAvailable = true,
    bool hasUsableVisualEvidence = true,
  }) {
    if (!decision.shouldNotifyClient) {
      return const MonitoringWatchClientNotificationGateDecision(
        shouldNotifyClient: false,
        summary: 'Suppressed because the scene remained below client threshold.',
      );
    }
    if (!monitoringAvailable) {
      return const MonitoringWatchClientNotificationGateDecision(
        shouldNotifyClient: false,
        summary:
            'Held for internal monitoring because the active watch does not currently have a live monitoring path.',
      );
    }
    if (!hasUsableVisualEvidence) {
      return const MonitoringWatchClientNotificationGateDecision(
        shouldNotifyClient: false,
        summary:
            'Held for internal monitoring because ONYX does not yet have a usable verification image for client delivery.',
      );
    }
    if (decision.kind != MonitoringWatchNotificationKind.escalationCandidate) {
      return const MonitoringWatchClientNotificationGateDecision(
        shouldNotifyClient: false,
        summary:
            'Held for internal monitoring because this update did not cross the client threat threshold.',
      );
    }
    final lastAt = runtime.latestClientNotificationAtUtc?.toUtc();
    if (lastAt == null) {
      return const MonitoringWatchClientNotificationGateDecision(
        shouldNotifyClient: true,
        summary:
            'Threat-routed client notification allowed because no prior automated threat message exists.',
      );
    }
    final now = occurredAtUtc.toUtc();
    final age = now.difference(lastAt);
    final lastSeverity = _severityForLabel(runtime.latestClientNotificationLabel);
    final nextSeverity = _severityForLabel(decision.incidentStatusLabel);
    final sameLabel =
        runtime.latestClientNotificationLabel.trim().toLowerCase() ==
        decision.incidentStatusLabel.trim().toLowerCase();

    if (age < minimumNotificationGap && nextSeverity <= lastSeverity) {
      return MonitoringWatchClientNotificationGateDecision(
        shouldNotifyClient: false,
        summary:
            'Suppressed because an equal-or-higher watch notification was already sent ${_formatAge(age)} ago.',
      );
    }
    if (sameLabel && age < repeatLabelCooldown) {
      return MonitoringWatchClientNotificationGateDecision(
        shouldNotifyClient: false,
        summary:
            'Suppressed because the lane already sent ${decision.incidentStatusLabel} ${_formatAge(age)} ago.',
      );
    }
    return MonitoringWatchClientNotificationGateDecision(
      shouldNotifyClient: true,
      summary: nextSeverity > lastSeverity
          ? 'Threat-routed client notification allowed because the lane posture escalated beyond the previous automated message.'
          : 'Threat-routed client notification allowed because the watch cooldown has elapsed.',
    );
  }

  int _severityForLabel(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'escalation candidate':
        return 3;
      case 'repeat activity':
        return 2;
      case 'monitoring alert':
        return 1;
      default:
        return 0;
    }
  }

  String _formatAge(Duration age) {
    final minutes = age.inMinutes;
    if (minutes <= 0) {
      return 'moments';
    }
    if (minutes == 1) {
      return '1 minute';
    }
    return '$minutes minutes';
  }
}
