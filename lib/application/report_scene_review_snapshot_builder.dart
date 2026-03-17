import '../domain/crm/reporting/report_sections.dart';
import '../domain/events/intelligence_received.dart';
import 'monitoring_scene_review_store.dart';
import 'hazard_response_directive_service.dart';

class ReportSceneReviewSnapshotBuilder {
  const ReportSceneReviewSnapshotBuilder();

  static const _hazardDirectiveService = HazardResponseDirectiveService();

  SceneReviewSnapshot build({
    required String month,
    required Iterable<IntelligenceReceived> intelligenceEvents,
    Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId =
        const {},
  }) {
    final scopedEvents = intelligenceEvents
        .where((event) => _monthKey(event.occurredAt) == month)
        .toList(growable: false);
    final reviewedEvents = scopedEvents
        .map(
          (event) => (
            event: event,
            review: sceneReviewByIntelligenceId[event.intelligenceId.trim()],
          ),
        )
        .where((entry) => entry.review != null)
        .map((entry) => (event: entry.event, review: entry.review!))
        .toList(growable: false);
    final totalReviews = reviewedEvents.length;
    final modelReviews = reviewedEvents
        .where((entry) => !_isMetadataFallback(entry.review.sourceLabel))
        .length;
    final metadataFallbackReviews = totalReviews - modelReviews;
    var suppressedActions = 0;
    var incidentAlerts = 0;
    var repeatUpdates = 0;
    var escalationCandidates = 0;
    for (final entry in reviewedEvents) {
      switch (_decisionBucket(entry.review)) {
        case _SceneReviewDecisionBucket.suppressed:
          suppressedActions += 1;
        case _SceneReviewDecisionBucket.incident:
          incidentAlerts += 1;
        case _SceneReviewDecisionBucket.repeat:
          repeatUpdates += 1;
        case _SceneReviewDecisionBucket.escalation:
          escalationCandidates += 1;
      }
    }
    final highlights = reviewedEvents.toList()
      ..sort((a, b) => b.event.occurredAt.compareTo(a.event.occurredAt));
    final latestActionTaken = _latestActionTaken(highlights);
    final latestSuppressedPattern = _latestSuppressedPattern(highlights);

    return SceneReviewSnapshot(
      totalReviews: totalReviews,
      modelReviews: modelReviews,
      metadataFallbackReviews: metadataFallbackReviews,
      suppressedActions: suppressedActions,
      incidentAlerts: incidentAlerts,
      repeatUpdates: repeatUpdates,
      escalationCandidates: escalationCandidates,
      topPosture: _topPosture(reviewedEvents),
      latestActionTaken: latestActionTaken,
      latestSuppressedPattern: latestSuppressedPattern,
      highlights: highlights
          .take(3)
          .map(
            (entry) => SceneReviewHighlightSnapshot(
              intelligenceId: entry.event.intelligenceId,
              detectedAt: entry.event.occurredAt.toUtc().toIso8601String(),
              cameraLabel: _cameraLabel(entry.event.cameraId),
              sourceLabel: entry.review.sourceLabel,
              postureLabel: entry.review.postureLabel,
              decisionLabel: entry.review.decisionLabel,
              decisionSummary: entry.review.decisionSummary,
              summary: entry.review.summary,
            ),
          )
          .toList(growable: false),
    );
  }

  static bool _isMetadataFallback(String sourceLabel) {
    final normalized = sourceLabel.trim().toLowerCase();
    return normalized == 'metadata-only' || normalized.startsWith('metadata:');
  }

  static String _topPosture(
    List<({IntelligenceReceived event, MonitoringSceneReviewRecord review})>
    reviews,
  ) {
    if (reviews.isEmpty) {
      return 'none';
    }
    final counts = <String, int>{};
    for (final entry in reviews) {
      final label = entry.review.postureLabel.trim();
      if (label.isEmpty) {
        continue;
      }
      counts.update(label, (value) => value + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) {
      return 'none';
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) {
          return byCount;
        }
        return a.key.compareTo(b.key);
      });
    return sorted.first.key;
  }

  static _SceneReviewDecisionBucket _decisionBucket(
    MonitoringSceneReviewRecord review,
  ) {
    final decision = review.decisionLabel.trim().toLowerCase();
    final posture = review.postureLabel.trim().toLowerCase();
    if (decision.contains('suppress')) {
      return _SceneReviewDecisionBucket.suppressed;
    }
    if (decision.contains('repeat')) {
      return _SceneReviewDecisionBucket.repeat;
    }
    if (decision.contains('escalation')) {
      return _SceneReviewDecisionBucket.escalation;
    }
    if (decision.contains('alert') || decision.contains('incident')) {
      return _SceneReviewDecisionBucket.incident;
    }
    if (_isHazardPosture(posture)) {
      return _SceneReviewDecisionBucket.escalation;
    }
    if (posture.contains('escalation')) {
      return _SceneReviewDecisionBucket.escalation;
    }
    if (posture.contains('repeat')) {
      return _SceneReviewDecisionBucket.repeat;
    }
    if (posture.isNotEmpty) {
      return _SceneReviewDecisionBucket.incident;
    }
    return _SceneReviewDecisionBucket.suppressed;
  }

  static bool _isHazardPosture(String posture) {
    return _hazardDirectiveService.isHazardSceneReviewPosture(
      postureLabel: posture,
    );
  }

  static String _latestSuppressedPattern(
    List<({IntelligenceReceived event, MonitoringSceneReviewRecord review})>
    reviews,
  ) {
    for (final entry in reviews) {
      if (_decisionBucket(entry.review) != _SceneReviewDecisionBucket.suppressed) {
        continue;
      }
      final detail = entry.review.decisionSummary.trim().isNotEmpty
          ? entry.review.decisionSummary.trim()
          : entry.review.summary.trim();
      return '${entry.event.occurredAt.toUtc().toIso8601String()} • ${_cameraLabel(entry.event.cameraId)} • $detail';
    }
    return '';
  }

  static String _latestActionTaken(
    List<({IntelligenceReceived event, MonitoringSceneReviewRecord review})>
    reviews,
  ) {
    for (final entry in reviews) {
      if (_decisionBucket(entry.review) == _SceneReviewDecisionBucket.suppressed) {
        continue;
      }
      final parts = <String>[
        entry.event.occurredAt.toUtc().toIso8601String(),
        _cameraLabel(entry.event.cameraId),
      ];
      final decisionLabel = entry.review.decisionLabel.trim();
      if (decisionLabel.isNotEmpty) {
        parts.add(decisionLabel);
      }
      final detail = entry.review.decisionSummary.trim().isNotEmpty
          ? entry.review.decisionSummary.trim()
          : entry.review.summary.trim();
      if (detail.isNotEmpty) {
        parts.add(detail);
      }
      return parts.join(' • ');
    }
    return '';
  }

  static String _cameraLabel(String? cameraId) {
    final normalized = (cameraId ?? '').trim();
    if (normalized.isEmpty) {
      return 'Unspecified';
    }
    final channelMatch = RegExp(r'^channel-(\d+)$').firstMatch(normalized);
    if (channelMatch != null) {
      return 'Camera ${channelMatch.group(1)}';
    }
    final digitsMatch = RegExp(r'^(\d+)$').firstMatch(normalized);
    if (digitsMatch != null) {
      return 'Camera ${digitsMatch.group(1)}';
    }
    return normalized;
  }

  static String _monthKey(DateTime utc) {
    final normalized = utc.toUtc();
    return '${normalized.year.toString().padLeft(4, '0')}-${normalized.month.toString().padLeft(2, '0')}';
  }
}

enum _SceneReviewDecisionBucket { suppressed, incident, repeat, escalation }
