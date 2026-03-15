import 'monitoring_watch_scene_assessment_service.dart';

enum MonitoringWatchNotificationKind {
  suppressed,
  incident,
  repeat,
  escalationCandidate,
}

class MonitoringWatchEscalationDecision {
  final MonitoringWatchNotificationKind kind;
  final String title;
  final String messageKeyPrefix;
  final String incidentStatusLabel;
  final String decisionSummary;
  final bool shouldNotifyClient;
  final bool shouldIncrementEscalation;

  const MonitoringWatchEscalationDecision({
    required this.kind,
    required this.title,
    required this.messageKeyPrefix,
    required this.incidentStatusLabel,
    required this.decisionSummary,
    required this.shouldNotifyClient,
    required this.shouldIncrementEscalation,
  });
}

class MonitoringWatchEscalationPolicyService {
  const MonitoringWatchEscalationPolicyService();

  MonitoringWatchEscalationDecision decide(
    MonitoringWatchSceneAssessment assessment,
  ) {
    if (!assessment.shouldNotifyClient) {
      final decisionSummary = assessment.temporaryIdentityAllowedSignal
          ? 'Suppressed because the matched identity has a one-time approval'
                '${assessment.temporaryIdentityValidUntilUtc == null ? '' : ' until ${assessment.temporaryIdentityValidUntilUtc!.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 16)} UTC'}'
                ' and the activity remained below the client notification threshold.'
          : assessment.identityAllowedSignal
          ? 'Suppressed because the matched identity is allowlisted for this site and the activity remained below the client notification threshold.'
          : 'Suppressed because the activity remained below the client notification threshold.';
      return MonitoringWatchEscalationDecision(
        kind: MonitoringWatchNotificationKind.suppressed,
        title: '',
        messageKeyPrefix: '',
        incidentStatusLabel: 'Suppressed',
        decisionSummary: decisionSummary,
        shouldNotifyClient: false,
        shouldIncrementEscalation: false,
      );
    }
    if (assessment.shouldEscalate) {
      return MonitoringWatchEscalationDecision(
        kind: MonitoringWatchNotificationKind.escalationCandidate,
        title: 'ONYX Escalation Review',
        messageKeyPrefix: 'tg-watch-auto-escalation',
        incidentStatusLabel: 'Escalation Candidate',
        decisionSummary: _decisionSummary(
          assessment,
          prefix: 'Escalated for urgent review because',
        ),
        shouldNotifyClient: true,
        shouldIncrementEscalation: true,
      );
    }
    if (assessment.repeatActivity) {
      return MonitoringWatchEscalationDecision(
        kind: MonitoringWatchNotificationKind.repeat,
        title: 'ONYX Monitoring Update',
        messageKeyPrefix: 'tg-watch-auto-repeat',
        incidentStatusLabel: 'Repeat Activity',
        decisionSummary: _decisionSummary(
          assessment,
          prefix: 'Repeat activity update sent because',
        ),
        shouldNotifyClient: true,
        shouldIncrementEscalation: true,
      );
    }
    return MonitoringWatchEscalationDecision(
      kind: MonitoringWatchNotificationKind.incident,
      title: 'ONYX Monitoring Alert',
      messageKeyPrefix: 'tg-watch-auto-alert',
      incidentStatusLabel: 'Monitoring Alert',
      decisionSummary: _decisionSummary(
        assessment,
        prefix: 'Client alert sent because',
      ),
      shouldNotifyClient: true,
      shouldIncrementEscalation: false,
    );
  }

  String _decisionSummary(
    MonitoringWatchSceneAssessment assessment, {
    required String prefix,
  }) {
    final reasons = <String>[];
    final objectLabel = assessment.objectLabel.trim().toLowerCase();
    if (objectLabel == 'person') {
      reasons.add('person activity was detected');
    } else if (objectLabel == 'vehicle') {
      reasons.add('vehicle activity was detected');
    } else if (objectLabel == 'animal') {
      reasons.add('animal activity was detected');
    } else if (objectLabel.isNotEmpty &&
        objectLabel != 'movement' &&
        objectLabel != 'motion') {
      reasons.add('$objectLabel activity was detected');
    } else {
      reasons.add('movement activity was detected');
    }

    if (assessment.repeatActivity) {
      reasons.add('the activity repeated');
    }
    if (assessment.faceMatchId != null &&
        assessment.faceMatchId!.trim().isNotEmpty) {
      if (assessment.identityRiskSignal) {
        reasons.add('face match ${assessment.faceMatchId!.trim()} was flagged');
      } else {
        reasons.add(
          'face match ${assessment.faceMatchId!.trim()} was captured',
        );
      }
    }
    if (assessment.plateNumber != null &&
        assessment.plateNumber!.trim().isNotEmpty) {
      if (assessment.identityRiskSignal) {
        reasons.add('plate ${assessment.plateNumber!.trim()} was flagged');
      } else {
        reasons.add('plate ${assessment.plateNumber!.trim()} was captured');
      }
    }
    if (assessment.identityRiskSignal) {
      reasons.add(
        'the event metadata suggested an unauthorized or watchlist context',
      );
    } else if (assessment.temporaryIdentityAllowedSignal) {
      final until = assessment.temporaryIdentityValidUntilUtc;
      if (until != null) {
        reasons.add(
          'the matched identity has a one-time approval until ${until.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 16)} UTC',
        );
      } else {
        reasons.add('the matched identity has a one-time approval');
      }
    } else if (assessment.identityAllowedSignal) {
      reasons.add('the matched identity is allowlisted for this site');
    }
    if (assessment.boundaryConcern) {
      reasons.add('the scene suggested boundary proximity');
    }
    if (assessment.loiteringConcern) {
      reasons.add('the scene suggested possible loitering');
    }
    if (assessment.groupedEventCount > 1) {
      reasons.add('${assessment.groupedEventCount} correlated signals arrived');
    }
    switch (assessment.confidence) {
      case MonitoringWatchSceneConfidence.high:
        reasons.add('confidence remained high');
      case MonitoringWatchSceneConfidence.medium:
        reasons.add('confidence remained medium');
      case MonitoringWatchSceneConfidence.low:
        reasons.add('confidence remained low');
    }
    return '$prefix ${_joinReasons(reasons)}.';
  }

  String _joinReasons(List<String> reasons) {
    if (reasons.isEmpty) {
      return 'the scene required further review';
    }
    if (reasons.length == 1) {
      return reasons.first;
    }
    if (reasons.length == 2) {
      return '${reasons.first} and ${reasons.last}';
    }
    final leading = reasons.take(reasons.length - 1).join(', ');
    return '$leading, and ${reasons.last}';
  }
}
