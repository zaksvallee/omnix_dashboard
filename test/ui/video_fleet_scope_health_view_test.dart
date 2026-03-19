import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_view.dart';

void main() {
  group('VideoFleetScopeHealthView', () {
    test('formats note text for quiet and pending scopes', () {
      const quiet = VideoFleetScopeHealthView(
        clientId: 'CLIENT-B',
        siteId: 'SITE-B',
        siteName: 'Beta Watch',
        endpointLabel: '192.168.8.106',
        statusLabel: 'WATCH READY',
        watchLabel: 'SCHEDULED',
        recentEvents: 0,
        lastSeenLabel: 'idle',
        freshnessLabel: 'Idle',
        isStale: false,
      );
      const pending = VideoFleetScopeHealthView(
        clientId: 'CLIENT-C',
        siteId: 'SITE-C',
        siteName: 'Gamma Watch',
        endpointLabel: '192.168.8.107',
        statusLabel: 'ACTIVE WATCH',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '20:14 UTC',
        freshnessLabel: 'Recent',
        isStale: false,
      );

      expect(quiet.noteText, 'No DVR incidents captured in the last 6 hours.');
      expect(
        pending.noteText,
        'Recent site activity is present, but no scope-linked incident reference is available yet.',
      );
    });

    test(
      'formats limited watch note with availability detail when present',
      () {
        const view = VideoFleetScopeHealthView(
          clientId: 'CLIENT-A',
          siteId: 'SITE-A',
          siteName: 'MS Vallee Residence',
          endpointLabel: '192.168.8.105',
          statusLabel: 'LIMITED WATCH',
          watchLabel: 'LIMITED',
          recentEvents: 0,
          lastSeenLabel: 'idle',
          freshnessLabel: 'Idle',
          isStale: false,
          monitoringAvailabilityDetail: 'One remote camera feed is stale.',
        );

        expect(
          view.limitedWatchStatusDetailText,
          'One remote camera feed is stale.',
        );
        expect(
          view.noteText,
          'Remote watch is limited: One remote camera feed is stale.',
        );
      },
    );

    test('formats latest summary text only when event label exists', () {
      const withTime = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestEventLabel: 'Vehicle motion',
        latestEventTimeLabel: '21:14 UTC',
      );
      const withoutTime = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestEventLabel: 'Vehicle motion',
      );
      const empty = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
      );

      expect(withTime.latestSummaryText, 'Latest: 21:14 UTC • Vehicle motion');
      expect(withoutTime.latestSummaryText, 'Vehicle motion');
      expect(empty.latestSummaryText, isNull);
    });

    test('formats recent action history text when present', () {
      const withOne = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        actionHistory: [
          '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
        ],
      );
      const withMany = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        actionHistory: [
          '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
          '21:05 UTC • Camera 1 • Repeat Activity • Repeat activity update sent because vehicle activity repeated.',
        ],
      );

      expect(
        withOne.latestActionHistoryText,
        'Recent action: 21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
      );
      expect(
        withMany.latestActionHistoryText,
        'Recent action: 21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium. (+1 more)',
      );
    });

    test('promotes recent action into prominent latest text when available', () {
      const withActionHistory = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        actionHistory: [
          '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
        ],
        latestEventLabel: 'Vehicle motion',
        latestEventTimeLabel: '21:14 UTC',
      );
      const withoutActionHistory = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestEventLabel: 'Vehicle motion',
        latestEventTimeLabel: '21:14 UTC',
      );

      expect(
        withActionHistory.prominentLatestText,
        'Recent action: 21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
      );
      expect(
        withoutActionHistory.prominentLatestText,
        'Latest: 21:14 UTC • Vehicle motion',
      );
      expect(withActionHistory.noteText?.contains('Recent action:'), isFalse);
    });

    test('formats identity match line when FR/LPR metadata exists', () {
      const view = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestFaceMatchId: 'PERSON-44',
        latestFaceConfidence: 91.2,
        latestPlateNumber: 'CA123456',
        latestPlateConfidence: 96.4,
        latestSceneReviewLabel:
            'openai:gpt-4.1-mini • identity match concern • 21:14 UTC',
        latestSceneDecisionSummary:
            'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
      );

      expect(view.identityPolicyText, 'Identity policy: Flagged match');
      expect(view.identityPolicyChipValue, 'Flagged');
      expect(
        view.identityMatchText,
        'Identity match: Face PERSON-44 91.2% • Plate CA123456 96.4%',
      );
      expect(view.noteText, contains('Identity policy: Flagged match'));
      expect(view.noteText, contains('Identity match: Face PERSON-44 91.2%'));
    });

    test('exposes allowlisted identity chip value', () {
      const view = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestFaceMatchId: 'RESIDENT-01',
        latestFaceConfidence: 94.1,
        latestPlateNumber: 'CA111111',
        latestPlateConfidence: 98.0,
        latestSceneReviewLabel:
            'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
        latestSceneDecisionSummary:
            'Suppressed because RESIDENT-01 and plate CA111111 are allowlisted for this site.',
      );

      expect(view.identityPolicyText, 'Identity policy: Allowlisted match');
      expect(view.identityPolicyChipValue, 'Allowlisted');
    });

    test('exposes temporary approval identity chip value', () {
      const view = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestFaceMatchId: 'VISITOR-01',
        latestFaceConfidence: 94.1,
        latestPlateNumber: 'CA777777',
        latestPlateConfidence: 98.0,
        latestSceneReviewLabel:
            'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
        latestSceneDecisionSummary:
            'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
      );

      expect(view.temporaryIdentityValidUntilText, '2026-03-15 18:00 UTC');
      expect(
        view.identityPolicyText,
        'Identity policy: Temporary approval until 2026-03-15 18:00 UTC',
      );
      expect(view.identityPolicyChipValue, 'Temporary');
    });

    test('derives temporary approval urgency from expiry window', () {
      const view = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestSceneDecisionSummary:
            'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
      );

      expect(
        view.temporaryIdentityValidUntilUtcValue,
        DateTime.utc(2026, 3, 15, 18, 0),
      );
      expect(
        view.temporaryIdentityUrgency(DateTime.utc(2026, 3, 15, 12, 0)),
        VideoFleetTemporaryIdentityUrgency.active,
      );
      expect(
        view.temporaryIdentityUrgency(DateTime.utc(2026, 3, 15, 15, 30)),
        VideoFleetTemporaryIdentityUrgency.warning,
      );
      expect(
        view.temporaryIdentityUrgency(DateTime.utc(2026, 3, 15, 17, 30)),
        VideoFleetTemporaryIdentityUrgency.critical,
      );
      expect(
        view.temporaryIdentityUrgency(DateTime.utc(2026, 3, 15, 18, 0)),
        VideoFleetTemporaryIdentityUrgency.expired,
      );
      expect(
        view.temporaryIdentityRemaining(DateTime.utc(2026, 3, 15, 17, 18)),
        const Duration(minutes: 42),
      );
      expect(
        view.temporaryIdentityCountdownText(DateTime.utc(2026, 3, 15, 17, 18)),
        'Temporary approval expires in 42m.',
      );
      expect(
        view.temporaryIdentityCountdownText(DateTime.utc(2026, 3, 15, 15, 30)),
        'Temporary approval expires in 2h 30m.',
      );
      expect(
        view.temporaryIdentityCountdownText(DateTime.utc(2026, 3, 13, 15, 0)),
        'Temporary approval expires in 2d 3h.',
      );
      expect(
        view.temporaryIdentityCountdownText(DateTime.utc(2026, 3, 15, 18, 1)),
        'Temporary approval expired.',
      );
    });

    test('includes temporary approval countdown in note text', () {
      final view = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestSceneReviewLabel:
            'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
        latestSceneDecisionSummary:
            'Suppressed because the matched identity has a one-time approval until 2099-03-15 18:00 UTC and the activity remained below the client notification threshold.',
      );

      expect(view.noteText, contains('Temporary approval expires in'));
    });

    test('formats client decision line and chip value when present', () {
      final view = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestClientDecisionLabel: 'Client Review Requested',
        latestClientDecisionSummary:
            'Client asked ONYX control to keep the event open for manual review.',
        latestClientDecisionAtUtc: DateTime.utc(2026, 3, 14, 21, 16),
      );

      expect(view.clientDecisionChipValue, 'Review');
      expect(
        view.clientDecisionText,
        'Client decision: 21:16 UTC • Client Review Requested • Client asked ONYX control to keep the event open for manual review.',
      );
      expect(view.noteText, contains('Client decision: 21:16 UTC'));
    });
  });
}
