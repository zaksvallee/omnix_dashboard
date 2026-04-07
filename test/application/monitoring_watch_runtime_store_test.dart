import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_runtime_store.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringWatchRuntimeStore', () {
    const store = MonitoringWatchRuntimeStore();

    test('parses persisted runtime state with numeric coercion', () {
      final restored = store.parsePersistedState({
        'CLIENT-A|SITE-A': <String, Object?>{
          'started_at_utc': '2026-03-14T10:00:00.000Z',
          'reviewed_events': '2',
          'primary_activity_source': 'Camera 1 ',
          'dispatch_count': 1.0,
          'alert_count': '1',
          'repeat_count': 2,
          'escalation_count': 3,
          'suppressed_count': '2',
          'action_history': [
            '10:04 UTC • Camera 1 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
          ],
          'monitoring_available': false,
          'monitoring_availability_detail': 'One remote camera feed is stale.',
          'unresolved_action_count': '4',
        },
        'CLIENT-B|SITE-B': <String, Object?>{'started_at_utc': ''},
      });

      expect(restored.keys, ['CLIENT-A|SITE-A']);
      final runtime = restored['CLIENT-A|SITE-A']!;
      expect(runtime.startedAtUtc, DateTime.utc(2026, 3, 14, 10, 0));
      expect(runtime.reviewedEvents, 2);
      expect(runtime.primaryActivitySource, 'Camera 1');
      expect(runtime.dispatchCount, 1);
      expect(runtime.alertCount, 1);
      expect(runtime.repeatCount, 2);
      expect(runtime.escalationCount, 3);
      expect(runtime.suppressedCount, 2);
      expect(runtime.monitoringAvailable, isFalse);
      expect(
        runtime.monitoringAvailabilityDetail,
        'One remote camera feed is stale.',
      );
      expect(runtime.unresolvedActionCount, 4);
      expect(runtime.latestSceneReviewSourceLabel, isEmpty);
      expect(runtime.latestSceneReviewSummary, isEmpty);
      expect(runtime.latestSceneDecisionLabel, isEmpty);
      expect(runtime.latestSceneDecisionSummary, isEmpty);
      expect(runtime.actionHistory, [
        '10:04 UTC • Camera 1 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
      ]);
      expect(runtime.suppressedHistory, isEmpty);
    });

    test('prepares persisted runtime state and clear behavior', () {
      final prepared = store.preparePersistedState({
        'CLIENT-A|SITE-A': MonitoringWatchRuntimeState(
          startedAtUtc: DateTime.utc(2026, 3, 14, 10, 0),
          reviewedEvents: 2,
          primaryActivitySource: 'Camera 1',
          dispatchCount: 1,
          alertCount: 1,
          repeatCount: 2,
          escalationCount: 3,
          suppressedCount: 2,
          actionHistory: const [
            '10:04 UTC • Camera 1 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
          ],
          monitoringAvailable: false,
          monitoringAvailabilityDetail: 'One remote camera feed is stale.',
          unresolvedActionCount: 4,
        ),
      });
      final empty = store.preparePersistedState(const {});

      expect(prepared.shouldClear, isFalse);
      expect(prepared.serializedState.keys, ['CLIENT-A|SITE-A']);
      expect(empty.shouldClear, isTrue);
      expect(empty.serializedState, isEmpty);
    });

    test('applies reviewed activity while preserving first source label', () {
      final updated = store.applyReviewedActivity(
        runtime: MonitoringWatchRuntimeState(
          startedAtUtc: DateTime.utc(2026, 3, 14, 10, 0),
          reviewedEvents: 1,
          primaryActivitySource: 'Camera 1',
          alertCount: 1,
          repeatCount: 1,
          escalationCount: 1,
          suppressedCount: 2,
          actionHistory: const [
            '10:01 UTC • Camera 1 • Repeat Activity • Repeat activity update sent because vehicle activity repeated.',
          ],
        ),
        reviewedEventDelta: 2,
        activitySource: 'Camera 3',
        alertDelta: 1,
        repeatDelta: 2,
        escalationDelta: 1,
        suppressedDelta: 2,
        sceneReviewSourceLabel: 'openai:gpt-4.1-mini',
        sceneReviewPostureLabel: 'escalation candidate',
        sceneDecisionLabel: 'Escalation Candidate',
        sceneDecisionSummary:
            'Escalated for urgent review because person activity was detected and confidence remained high.',
        sceneReviewSummary: 'Person visible near the boundary line.',
        sceneReviewRecordedAtUtc: DateTime.utc(2026, 3, 14, 10, 5),
      );

      expect(updated.reviewedEvents, 3);
      expect(updated.primaryActivitySource, 'Camera 1');
      expect(updated.alertCount, 2);
      expect(updated.repeatCount, 3);
      expect(updated.escalationCount, 2);
      expect(updated.actionHistory, [
        '10:05 UTC • Camera 3 • Escalation Candidate • Escalated for urgent review because person activity was detected and confidence remained high.',
        '10:01 UTC • Camera 1 • Repeat Activity • Repeat activity update sent because vehicle activity repeated.',
      ]);
      expect(updated.suppressedCount, 4);
      expect(updated.suppressedHistory, [
        '10:05 UTC • Camera 3 • Escalated for urgent review because person activity was detected and confidence remained high.',
      ]);
      expect(updated.latestSceneReviewSourceLabel, 'openai:gpt-4.1-mini');
      expect(updated.latestSceneReviewPostureLabel, 'escalation candidate');
      expect(updated.latestSceneDecisionLabel, 'Escalation Candidate');
      expect(
        updated.latestSceneDecisionSummary,
        contains('Escalated for urgent review'),
      );
      expect(
        updated.latestSceneReviewSummary,
        'Person visible near the boundary line.',
      );
      expect(
        updated.latestSceneReviewUpdatedAtUtc,
        DateTime.utc(2026, 3, 14, 10, 5),
      );
    });

    test('parses persisted scene review context', () {
      final restored = store.parsePersistedState({
        'CLIENT-A|SITE-A': <String, Object?>{
          'started_at_utc': '2026-03-14T10:00:00.000Z',
          'latest_scene_review_source_label': 'openai:gpt-4.1-mini',
          'latest_scene_review_posture_label': 'repeat monitored activity',
          'latest_scene_review_summary':
              'Vehicle remains in the approach lane.',
          'latest_scene_decision_label': 'Repeat Activity',
          'latest_scene_decision_summary':
              'Repeat activity update sent because vehicle activity was detected and the activity repeated.',
          'latest_client_decision_label': 'Client Approved',
          'latest_client_decision_summary':
              'Client confirmed the unidentified person was expected.',
          'latest_client_decision_at_utc': '2026-03-14T10:06:00.000Z',
          'alert_count': 1,
          'repeat_count': 2,
          'suppressed_count': 1,
          'action_history': [
            '10:04 UTC • Camera 2 • Repeat Activity • Repeat activity update sent because vehicle activity was detected and the activity repeated.',
          ],
          'suppressed_history': [
            '10:05 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
          ],
          'latest_scene_review_updated_at_utc': '2026-03-14T10:05:00.000Z',
        },
      });

      final runtime = restored['CLIENT-A|SITE-A']!;
      expect(runtime.latestSceneReviewSourceLabel, 'openai:gpt-4.1-mini');
      expect(
        runtime.latestSceneReviewPostureLabel,
        'repeat monitored activity',
      );
      expect(
        runtime.latestSceneReviewSummary,
        'Vehicle remains in the approach lane.',
      );
      expect(runtime.latestSceneDecisionLabel, 'Repeat Activity');
      expect(runtime.latestClientDecisionLabel, 'Client Approved');
      expect(
        runtime.latestClientDecisionSummary,
        'Client confirmed the unidentified person was expected.',
      );
      expect(
        runtime.latestClientDecisionAtUtc,
        DateTime.utc(2026, 3, 14, 10, 6),
      );
      expect(runtime.alertCount, 1);
      expect(runtime.repeatCount, 2);
      expect(runtime.suppressedCount, 1);
      expect(runtime.actionHistory, [
        '10:04 UTC • Camera 2 • Repeat Activity • Repeat activity update sent because vehicle activity was detected and the activity repeated.',
      ]);
      expect(runtime.suppressedHistory, [
        '10:05 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
      ]);
      expect(
        runtime.latestSceneDecisionSummary,
        contains('Repeat activity update sent'),
      );
      expect(
        runtime.latestSceneReviewUpdatedAtUtc,
        DateTime.utc(2026, 3, 14, 10, 5),
      );
    });

    test('persists tracked subjects and prunes stale history', () {
      final runtime = store.applyTrackedActivity(
        runtime: MonitoringWatchRuntimeState(
          startedAtUtc: DateTime.utc(2026, 3, 14, 10, 0),
          trackedSubjects: {
            'track-stale': MonitoringWatchTrackedSubjectState(
              trackId: 'track-stale',
              cameraId: 'CAM-2',
              objectLabel: 'person',
              firstSeenAtUtc: DateTime.utc(2026, 3, 14, 9, 30),
              lastSeenAtUtc: DateTime.utc(2026, 3, 14, 9, 40),
              eventCount: 2,
            ),
          },
        ),
        events: [
          _intel(
            id: 'track-1',
            occurredAt: DateTime.utc(2026, 3, 14, 10, 4),
            cameraId: 'CAM-1',
            objectLabel: 'person',
            trackId: 'track-7',
          ),
          _intel(
            id: 'track-2',
            occurredAt: DateTime.utc(2026, 3, 14, 10, 7),
            cameraId: 'CAM-1',
            objectLabel: 'person',
            trackId: 'track-7',
          ),
        ],
        observedAtUtc: DateTime.utc(2026, 3, 14, 10, 7),
      );

      expect(runtime.trackedSubjects.keys, ['track-7']);
      final tracked = runtime.trackedSubjects['track-7']!;
      expect(tracked.cameraId, 'CAM-1');
      expect(tracked.objectLabel, 'person');
      expect(tracked.firstSeenAtUtc, DateTime.utc(2026, 3, 14, 10, 4));
      expect(tracked.lastSeenAtUtc, DateTime.utc(2026, 3, 14, 10, 7));
      expect(tracked.eventCount, 2);

      final prepared = store.preparePersistedState({
        'CLIENT-A|SITE-A': runtime,
      });
      final restored = store.parsePersistedState(prepared.serializedState);
      expect(restored['CLIENT-A|SITE-A']!.trackedSubjects.keys, ['track-7']);
      expect(
        restored['CLIENT-A|SITE-A']!.trackedSubjects['track-7']!.eventCount,
        2,
      );
    });

    test(
      'persists semantic person and vehicle labels for FR and LPR tracked subjects',
      () {
        final runtime = store.applyTrackedActivity(
          runtime: MonitoringWatchRuntimeState(
            startedAtUtc: DateTime.utc(2026, 3, 14, 10, 0),
          ),
          events: [
            _intel(
              id: 'track-fr',
              occurredAt: DateTime.utc(2026, 3, 14, 10, 4),
              cameraId: 'CAM-LOBBY',
              objectLabel: '',
              trackId: 'track-fr-1',
              faceMatchId: 'RESIDENT-44',
            ),
            _intel(
              id: 'track-lpr',
              occurredAt: DateTime.utc(2026, 3, 14, 10, 5),
              cameraId: 'CAM-DRIVE',
              objectLabel: '',
              trackId: 'track-lpr-1',
              plateNumber: 'CA123456',
            ),
          ],
          observedAtUtc: DateTime.utc(2026, 3, 14, 10, 5),
        );

        expect(runtime.trackedSubjects['track-fr-1']!.objectLabel, 'person');
        expect(runtime.trackedSubjects['track-lpr-1']!.objectLabel, 'vehicle');

        final prepared = store.preparePersistedState({
          'CLIENT-A|SITE-A': runtime,
        });
        final restored = store.parsePersistedState(prepared.serializedState);

        expect(
          restored['CLIENT-A|SITE-A']!
              .trackedSubjects['track-fr-1']!
              .objectLabel,
          'person',
        );
        expect(
          restored['CLIENT-A|SITE-A']!
              .trackedSubjects['track-lpr-1']!
              .objectLabel,
          'vehicle',
        );
      },
    );

    test('applies client decision context to runtime', () {
      final updated = store.applyClientDecision(
        runtime: MonitoringWatchRuntimeState(
          startedAtUtc: DateTime.utc(2026, 3, 14, 10, 0),
        ),
        decisionLabel: 'Client Review Requested',
        decisionSummary:
            'Client asked ONYX control to keep the event open for manual review.',
        decidedAtUtc: DateTime.utc(2026, 3, 14, 10, 7),
      );

      expect(updated.latestClientDecisionLabel, 'Client Review Requested');
      expect(
        updated.latestClientDecisionSummary,
        'Client asked ONYX control to keep the event open for manual review.',
      );
      expect(
        updated.latestClientDecisionAtUtc,
        DateTime.utc(2026, 3, 14, 10, 7),
      );
    });

    test('builds capped action history with fallback labels and summaries', () {
      var runtime = MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 14, 10, 0),
      );

      runtime = store.applyReviewedActivity(
        runtime: runtime,
        reviewedEventDelta: 1,
        activitySource: 'Camera 1',
        alertDelta: 1,
        sceneReviewRecordedAtUtc: DateTime.utc(2026, 3, 14, 10, 1),
      );
      runtime = store.applyReviewedActivity(
        runtime: runtime,
        reviewedEventDelta: 1,
        activitySource: 'Camera 2',
        repeatDelta: 1,
        sceneReviewRecordedAtUtc: DateTime.utc(2026, 3, 14, 10, 2),
      );
      runtime = store.applyReviewedActivity(
        runtime: runtime,
        reviewedEventDelta: 1,
        activitySource: 'Camera 3',
        escalationDelta: 1,
        sceneReviewRecordedAtUtc: DateTime.utc(2026, 3, 14, 10, 3),
      );
      runtime = store.applyReviewedActivity(
        runtime: runtime,
        reviewedEventDelta: 1,
        activitySource: 'Camera 4',
        alertDelta: 1,
        sceneReviewRecordedAtUtc: DateTime.utc(2026, 3, 14, 10, 4),
      );

      expect(runtime.actionHistory, [
        '10:04 UTC • Camera 4 • Monitoring Alert • Client alert issued from watch review.',
        '10:03 UTC • Camera 3 • Escalation Candidate • Escalated for urgent watch review.',
        '10:02 UTC • Camera 2 • Repeat Activity • Repeat activity update issued from watch review.',
      ]);
    });
  });
}

IntelligenceReceived _intel({
  required String id,
  required DateTime occurredAt,
  String? cameraId,
  String? objectLabel,
  String? trackId,
  String? faceMatchId,
  String? plateNumber,
}) {
  return IntelligenceReceived(
    eventId: 'event-$id',
    sequence: 1,
    version: 1,
    occurredAt: occurredAt,
    intelligenceId: id,
    provider: 'test-provider',
    sourceType: 'dvr',
    externalId: 'ext-$id',
    clientId: 'CLIENT-A',
    regionId: 'REGION-A',
    siteId: 'SITE-A',
    cameraId: cameraId,
    objectLabel: objectLabel,
    objectConfidence: 0.8,
    trackId: trackId,
    faceMatchId: faceMatchId,
    plateNumber: plateNumber,
    headline: 'Test event',
    summary: 'Tracked subject event',
    riskScore: 45,
    canonicalHash: 'hash-$id',
  );
}
