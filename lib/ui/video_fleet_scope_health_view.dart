enum VideoFleetTemporaryIdentityUrgency { active, warning, critical, expired }

class VideoFleetScopeHealthView {
  final String clientId;
  final String siteId;
  final String siteName;
  final String endpointLabel;
  final String statusLabel;
  final String watchLabel;
  final int recentEvents;
  final String lastSeenLabel;
  final String freshnessLabel;
  final bool isStale;
  final String? watchWindowLabel;
  final String? watchWindowStateLabel;
  final String? watchActivationGapLabel;
  final String? monitoringAvailabilityDetail;
  final String? operatorOutcomeLabel;
  final String? lastRecoveryLabel;
  final String? latestSceneReviewLabel;
  final String? latestSceneReviewSummary;
  final String? latestSceneDecisionLabel;
  final String? latestSceneDecisionSummary;
  final String? latestClientDecisionLabel;
  final String? latestClientDecisionSummary;
  final DateTime? latestClientDecisionAtUtc;
  final int alertCount;
  final int repeatCount;
  final int escalationCount;
  final int suppressedCount;
  final List<String> actionHistory;
  final List<String> suppressedHistory;
  final String? latestEventLabel;
  final String? latestIncidentReference;
  final String? latestEventTimeLabel;
  final String? latestCameraLabel;
  final int? latestRiskScore;
  final String? latestFaceMatchId;
  final double? latestFaceConfidence;
  final String? latestPlateNumber;
  final double? latestPlateConfidence;

  const VideoFleetScopeHealthView({
    required this.clientId,
    required this.siteId,
    required this.siteName,
    required this.endpointLabel,
    required this.statusLabel,
    required this.watchLabel,
    required this.recentEvents,
    required this.lastSeenLabel,
    required this.freshnessLabel,
    required this.isStale,
    this.watchWindowLabel,
    this.watchWindowStateLabel,
    this.watchActivationGapLabel,
    this.monitoringAvailabilityDetail,
    this.operatorOutcomeLabel,
    this.lastRecoveryLabel,
    this.latestSceneReviewLabel,
    this.latestSceneReviewSummary,
    this.latestSceneDecisionLabel,
    this.latestSceneDecisionSummary,
    this.latestClientDecisionLabel,
    this.latestClientDecisionSummary,
    this.latestClientDecisionAtUtc,
    this.alertCount = 0,
    this.repeatCount = 0,
    this.escalationCount = 0,
    this.suppressedCount = 0,
    this.actionHistory = const <String>[],
    this.suppressedHistory = const <String>[],
    this.latestEventLabel,
    this.latestIncidentReference,
    this.latestEventTimeLabel,
    this.latestCameraLabel,
    this.latestRiskScore,
    this.latestFaceMatchId,
    this.latestFaceConfidence,
    this.latestPlateNumber,
    this.latestPlateConfidence,
  });

  bool get hasIncidentContext =>
      (latestIncidentReference ?? '').trim().isNotEmpty;

  bool get hasWatchActivationGap =>
      (watchActivationGapLabel ?? '').trim().isNotEmpty;

  bool get hasRecentRecovery => (lastRecoveryLabel ?? '').trim().isNotEmpty;

  bool get hasSuppressedSceneAction {
    final label = (latestSceneDecisionLabel ?? '').trim().toLowerCase();
    final summary = (latestSceneDecisionSummary ?? '').trim().toLowerCase();
    return label.contains('suppress') || summary.contains('suppress');
  }

  String? get limitedWatchStatusDetailText {
    if (watchLabel != 'LIMITED') {
      return null;
    }
    final detail = (monitoringAvailabilityDetail ?? '').trim();
    if (detail.isNotEmpty) {
      return detail;
    }
    return 'Manual verification may be needed.';
  }

  String? get noteText {
    final suppressedSummary = suppressedActivityText;
    final actionMix = watchActionMixText;
    final sceneAction = sceneDecisionText;
    final sceneReview = sceneReviewText;
    final parts = <String>[];
    if (watchLabel == 'LIMITED') {
      final detail = limitedWatchStatusDetailText;
      parts.add(
        detail == null || detail.isEmpty
            ? 'Remote watch is limited. Manual verification may be needed.'
            : 'Remote watch is limited: $detail',
      );
    }
    if (suppressedSummary != null) {
      parts.add(suppressedSummary);
    }
    if (actionMix != null) {
      parts.add(actionMix);
    }
    final suppressedHistoryText = latestSuppressedHistoryText;
    if (suppressedHistoryText != null) {
      parts.add(suppressedHistoryText);
    }
    final identityPolicy = identityPolicyText;
    if (identityPolicy != null) {
      parts.add(identityPolicy);
    }
    final temporaryCountdown = temporaryIdentityCountdownText();
    if (temporaryCountdown != null) {
      parts.add(temporaryCountdown);
    }
    final clientDecision = clientDecisionText;
    if (clientDecision != null) {
      parts.add(clientDecision);
    }
    final identityMatch = identityMatchText;
    if (identityMatch != null) {
      parts.add(identityMatch);
    }
    if (sceneAction != null) {
      parts.add(sceneAction);
    }
    if (sceneReview != null) {
      parts.add(sceneReview);
    }
    if (parts.isNotEmpty) {
      return parts.join('\n');
    }
    if (hasIncidentContext) {
      return null;
    }
    return recentEvents == 0
        ? 'No DVR incidents captured in the last 6 hours.'
        : 'Recent site activity is present, but no scope-linked incident reference is available yet.';
  }

  String? get latestSummaryText {
    final label = (latestEventLabel ?? '').trim();
    if (label.isEmpty) {
      return null;
    }
    final time = (latestEventTimeLabel ?? '').trim();
    if (time.isEmpty) {
      return label;
    }
    return 'Latest: $time • $label';
  }

  String? get sceneReviewText {
    final summary = (latestSceneReviewSummary ?? '').trim();
    final label = (latestSceneReviewLabel ?? '').trim();
    if (summary.isEmpty && label.isEmpty) {
      return null;
    }
    if (label.isEmpty) {
      return 'Scene review: $summary';
    }
    if (summary.isEmpty) {
      return 'Scene review: $label';
    }
    return 'Scene review: $label • $summary';
  }

  String? get sceneDecisionText {
    final summary = (latestSceneDecisionSummary ?? '').trim();
    final label = (latestSceneDecisionLabel ?? '').trim();
    if (summary.isEmpty && label.isEmpty) {
      return null;
    }
    if (label.isEmpty) {
      return 'Scene action: $summary';
    }
    if (summary.isEmpty) {
      return 'Scene action: $label';
    }
    return 'Scene action: $label • $summary';
  }

  String? get clientDecisionText {
    final label = (latestClientDecisionLabel ?? '').trim();
    final summary = (latestClientDecisionSummary ?? '').trim();
    final decidedAt = latestClientDecisionAtUtc;
    if (label.isEmpty && summary.isEmpty && decidedAt == null) {
      return null;
    }
    final parts = <String>[];
    if (decidedAt != null) {
      final utc = decidedAt.toUtc();
      parts.add(
        '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')} UTC',
      );
    }
    if (label.isNotEmpty) {
      parts.add(label);
    }
    if (summary.isNotEmpty) {
      parts.add(summary);
    }
    if (parts.isEmpty) {
      return null;
    }
    return 'Client decision: ${parts.join(' • ')}';
  }

  String? get suppressedActivityText {
    if (suppressedCount <= 0) {
      return null;
    }
    final countLabel = suppressedCount == 1
        ? '1 review'
        : '$suppressedCount reviews';
    return 'Suppressed in watch: $countLabel filtered.';
  }

  String? get latestSuppressedHistoryText {
    if (suppressedHistory.isEmpty) {
      return null;
    }
    final latest = suppressedHistory.first.trim();
    if (latest.isEmpty) {
      return null;
    }
    final remaining = suppressedHistory.length - 1;
    if (remaining <= 0) {
      return 'Latest filtered: $latest';
    }
    return 'Latest filtered: $latest (+$remaining more)';
  }

  String? get latestActionHistoryText {
    if (actionHistory.isEmpty) {
      return null;
    }
    final latest = actionHistory.first.trim();
    if (latest.isEmpty) {
      return null;
    }
    final remaining = actionHistory.length - 1;
    if (remaining <= 0) {
      return 'Recent action: $latest';
    }
    return 'Recent action: $latest (+$remaining more)';
  }

  String? get identityMatchText {
    final parts = <String>[];
    final face = (latestFaceMatchId ?? '').trim();
    if (face.isNotEmpty) {
      final confidence = _confidenceLabel(latestFaceConfidence);
      parts.add(confidence == null ? 'Face $face' : 'Face $face $confidence');
    }
    final plate = (latestPlateNumber ?? '').trim();
    if (plate.isNotEmpty) {
      final confidence = _confidenceLabel(latestPlateConfidence);
      parts.add(
        confidence == null ? 'Plate $plate' : 'Plate $plate $confidence',
      );
    }
    if (parts.isEmpty) {
      return null;
    }
    return 'Identity match: ${parts.join(' • ')}';
  }

  String? get identityPolicyText {
    final sceneReviewLabel = (latestSceneReviewLabel ?? '')
        .trim()
        .toLowerCase();
    final sceneDecisionSummaryRaw = (latestSceneDecisionSummary ?? '').trim();
    final sceneDecisionSummary = sceneDecisionSummaryRaw.toLowerCase();
    if (sceneDecisionSummary.contains('one-time approval') ||
        sceneDecisionSummary.contains('one time approval')) {
      final until = temporaryIdentityValidUntilText;
      if (until != null) {
        return 'Identity policy: Temporary approval until $until';
      }
      return 'Identity policy: Temporary approval';
    }
    if (sceneReviewLabel.contains('known allowed identity') ||
        sceneDecisionSummary.contains('allowlisted for this site')) {
      return 'Identity policy: Allowlisted match';
    }
    if (sceneReviewLabel.contains('identity match concern') ||
        sceneDecisionSummary.contains('was flagged') ||
        sceneDecisionSummary.contains('watchlist context') ||
        sceneDecisionSummary.contains('unauthorized or watchlist context')) {
      return 'Identity policy: Flagged match';
    }
    return null;
  }

  bool get hasFlaggedIdentityPolicy =>
      identityPolicyText == 'Identity policy: Flagged match';

  bool get hasAllowlistedIdentityPolicy =>
      identityPolicyText == 'Identity policy: Allowlisted match';

  bool get hasTemporaryIdentityPolicy => (identityPolicyText ?? '').startsWith(
    'Identity policy: Temporary approval',
  );

  String? get temporaryIdentityValidUntilText {
    final summary = (latestSceneDecisionSummary ?? '').trim();
    if (summary.isEmpty) {
      return null;
    }
    final match = RegExp(
      r'until\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\s+UTC)',
      caseSensitive: false,
    ).firstMatch(summary);
    return match?.group(1);
  }

  DateTime? get temporaryIdentityValidUntilUtcValue {
    final until = temporaryIdentityValidUntilText;
    if (until == null) {
      return null;
    }
    final normalized = until
        .replaceFirst(' UTC', ':00Z')
        .replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized)?.toUtc();
  }

  VideoFleetTemporaryIdentityUrgency? temporaryIdentityUrgency([
    DateTime? referenceUtc,
  ]) {
    final until = temporaryIdentityValidUntilUtcValue;
    if (until == null) {
      return null;
    }
    final reference = (referenceUtc ?? DateTime.now()).toUtc();
    if (!until.isAfter(reference)) {
      return VideoFleetTemporaryIdentityUrgency.expired;
    }
    final remaining = until.difference(reference);
    if (remaining <= const Duration(hours: 1)) {
      return VideoFleetTemporaryIdentityUrgency.critical;
    }
    if (remaining <= const Duration(hours: 4)) {
      return VideoFleetTemporaryIdentityUrgency.warning;
    }
    return VideoFleetTemporaryIdentityUrgency.active;
  }

  Duration? temporaryIdentityRemaining([DateTime? referenceUtc]) {
    final until = temporaryIdentityValidUntilUtcValue;
    if (until == null) {
      return null;
    }
    return until.difference((referenceUtc ?? DateTime.now()).toUtc());
  }

  String? temporaryIdentityCountdownText([DateTime? referenceUtc]) {
    if (!hasTemporaryIdentityPolicy) {
      return null;
    }
    final remaining = temporaryIdentityRemaining(referenceUtc);
    if (remaining == null) {
      return null;
    }
    if (remaining <= Duration.zero) {
      return 'Temporary approval expired.';
    }
    return 'Temporary approval expires in ${_durationLabel(remaining)}.';
  }

  String? get identityPolicyChipValue {
    if (hasFlaggedIdentityPolicy) {
      return 'Flagged';
    }
    if (hasTemporaryIdentityPolicy) {
      return 'Temporary';
    }
    if (hasAllowlistedIdentityPolicy) {
      return 'Allowlisted';
    }
    return null;
  }

  String? get clientDecisionChipValue {
    final label = (latestClientDecisionLabel ?? '').trim().toLowerCase();
    if (label.contains('approved')) {
      return 'Approved';
    }
    if (label.contains('review')) {
      return 'Review';
    }
    if (label.contains('escalat')) {
      return 'Escalated';
    }
    return null;
  }

  String? get watchActionMixText {
    final parts = <String>[];
    if (alertCount > 0) {
      parts.add(alertCount == 1 ? 'Alert 1' : 'Alerts $alertCount');
    }
    if (repeatCount > 0) {
      parts.add(repeatCount == 1 ? 'Repeat 1' : 'Repeat $repeatCount');
    }
    if (escalationCount > 0) {
      parts.add(
        escalationCount == 1 ? 'Escalated 1' : 'Escalated $escalationCount',
      );
    }
    if (suppressedCount > 0) {
      parts.add(
        suppressedCount == 1 ? 'Suppressed 1' : 'Suppressed $suppressedCount',
      );
    }
    if (parts.isEmpty) {
      return null;
    }
    return 'Action mix in watch: ${parts.join(' • ')}.';
  }

  String? get prominentLatestText =>
      latestActionHistoryText ?? latestSummaryText;

  String? _confidenceLabel(double? confidence) {
    if (confidence == null) {
      return null;
    }
    return '${confidence.toStringAsFixed(1)}%';
  }

  String _durationLabel(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = totalMinutes.remainder(60);
    final parts = <String>[];
    if (days > 0) {
      parts.add('${days}d');
    }
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0 && days == 0) {
      parts.add('${minutes}m');
    }
    return parts.join(' ');
  }
}
