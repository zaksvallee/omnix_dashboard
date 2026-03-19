import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_view.dart';

void main() {
  group('VideoFleetScopeHealthSections', () {
    test('partitions scopes and computes summary counts', () {
      final sections = VideoFleetScopeHealthSections.fromScopes(const [
        VideoFleetScopeHealthView(
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
          latestIncidentReference: 'INT-VALLEE-1',
          latestEventTimeLabel: '21:14 UTC',
          latestCameraLabel: 'Camera 1',
          latestRiskScore: 84,
          latestSceneReviewLabel: 'identity match concern',
          latestSceneDecisionSummary:
              'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
        ),
        VideoFleetScopeHealthView(
          clientId: 'CLIENT-B',
          siteId: 'SITE-B',
          siteName: 'Beta Watch',
          endpointLabel: '192.168.8.106',
          statusLabel: 'ACTIVE WATCH',
          watchLabel: 'ACTIVE',
          recentEvents: 1,
          lastSeenLabel: '20:00 UTC',
          freshnessLabel: 'Stale',
          isStale: true,
          alertCount: 1,
          repeatCount: 2,
          escalationCount: 1,
          suppressedCount: 3,
          lastRecoveryLabel: 'ADMIN • Resynced • 20:58 UTC',
          latestSceneDecisionLabel: 'Suppressed',
          latestSceneDecisionSummary:
              'Suppressed because the activity remained below the client notification threshold.',
          watchActivationGapLabel: 'MISSED START',
        ),
      ]);

      expect(sections.actionableScopes, hasLength(1));
      expect(sections.watchOnlyScopes, hasLength(1));
      expect(sections.activeCount, 2);
      expect(sections.limitedCount, 0);
      expect(sections.gapCount, 1);
      expect(sections.highRiskCount, 1);
      expect(sections.recoveredCount, 1);
      expect(sections.suppressedCount, 1);
      expect(sections.alertActionCount, 1);
      expect(sections.repeatActionCount, 2);
      expect(sections.escalationActionCount, 1);
      expect(sections.suppressedActionCount, 3);
      expect(sections.flaggedIdentityCount, 1);
      expect(sections.temporaryIdentityCount, 0);
      expect(sections.allowlistedIdentityCount, 0);
      expect(sections.staleCount, 1);
      expect(sections.noIncidentCount, 1);
      expect(sections.actionableLabel, 'Incident-backed fleet scopes');
      expect(sections.watchOnlyLabel, 'Watch scopes awaiting incident context');
    });

    test('returns empty-state labels when no scopes match a section', () {
      final sections = VideoFleetScopeHealthSections.fromScopes(const [
        VideoFleetScopeHealthView(
          clientId: 'CLIENT-A',
          siteId: 'SITE-A',
          siteName: 'MS Vallee Residence',
          endpointLabel: '192.168.8.105',
          statusLabel: 'WATCH READY',
          watchLabel: 'SCHEDULED',
          recentEvents: 0,
          lastSeenLabel: 'idle',
          freshnessLabel: 'Idle',
          isStale: false,
        ),
      ]);

      expect(
        sections.actionableLabel,
        'No incident-backed fleet scopes right now',
      );
      expect(sections.gapCount, 0);
      expect(sections.recoveredCount, 0);
      expect(sections.suppressedCount, 0);
      expect(sections.alertActionCount, 0);
      expect(sections.repeatActionCount, 0);
      expect(sections.escalationActionCount, 0);
      expect(sections.suppressedActionCount, 0);
      expect(sections.watchOnlyLabel, 'Watch scopes awaiting incident context');
    });

    test('counts limited watch scopes as active coverage', () {
      final sections = VideoFleetScopeHealthSections.fromScopes(const [
        VideoFleetScopeHealthView(
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
        ),
        VideoFleetScopeHealthView(
          clientId: 'CLIENT-B',
          siteId: 'SITE-B',
          siteName: 'Sandton Tower',
          endpointLabel: '192.168.8.106',
          statusLabel: 'ACTIVE WATCH',
          watchLabel: 'ACTIVE',
          recentEvents: 0,
          lastSeenLabel: 'idle',
          freshnessLabel: 'Idle',
          isStale: false,
        ),
      ]);

      expect(sections.activeCount, 2);
      expect(sections.limitedCount, 1);
    });

    test('filters scopes by active watch action drilldown', () {
      const scopes = [
        VideoFleetScopeHealthView(
          clientId: 'CLIENT-A',
          siteId: 'SITE-A',
          siteName: 'Alpha',
          endpointLabel: '10.0.0.1',
          statusLabel: 'LIMITED WATCH',
          watchLabel: 'LIMITED',
          recentEvents: 1,
          lastSeenLabel: '21:14 UTC',
          freshnessLabel: 'Fresh',
          isStale: false,
          monitoringAvailabilityDetail: 'One remote camera feed is stale.',
          alertCount: 1,
          latestIncidentReference: 'INC-1',
          latestSceneReviewLabel: 'identity match concern',
        ),
        VideoFleetScopeHealthView(
          clientId: 'CLIENT-B',
          siteId: 'SITE-B',
          siteName: 'Beta',
          endpointLabel: '10.0.0.2',
          statusLabel: 'WATCH READY',
          watchLabel: 'SCHEDULED',
          recentEvents: 1,
          lastSeenLabel: '21:16 UTC',
          freshnessLabel: 'Recent',
          isStale: false,
          suppressedCount: 2,
          latestSceneReviewLabel: 'known allowed identity',
          latestSceneDecisionSummary:
              'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
        ),
      ];

      expect(
        filterFleetScopesForWatchAction(
          scopes,
          VideoFleetWatchActionDrilldown.limited,
        ).map((scope) => scope.siteName),
        ['Alpha'],
      );
      expect(
        filterFleetScopesForWatchAction(
          scopes,
          VideoFleetWatchActionDrilldown.alerts,
        ).map((scope) => scope.siteName),
        ['Alpha'],
      );
      expect(
        filterFleetScopesForWatchAction(
          scopes,
          VideoFleetWatchActionDrilldown.filtered,
        ).map((scope) => scope.siteName),
        ['Beta'],
      );
      expect(
        filterFleetScopesForWatchAction(
          scopes,
          VideoFleetWatchActionDrilldown.flaggedIdentity,
        ).map((scope) => scope.siteName),
        ['Alpha'],
      );
      expect(
        filterFleetScopesForWatchAction(
          scopes,
          VideoFleetWatchActionDrilldown.temporaryIdentity,
        ).map((scope) => scope.siteName),
        ['Beta'],
      );
      expect(
        filterFleetScopesForWatchAction(
          scopes,
          VideoFleetWatchActionDrilldown.allowlistedIdentity,
        ).map((scope) => scope.siteName),
        isEmpty,
      );
    });

    test('derives drilldown-aware section labels', () {
      final sections = VideoFleetScopeHealthSections.fromScopes(const [
        VideoFleetScopeHealthView(
          clientId: 'CLIENT-A',
          siteId: 'SITE-A',
          siteName: 'Alpha',
          endpointLabel: '10.0.0.1',
          statusLabel: 'LIVE',
          watchLabel: 'ACTIVE',
          recentEvents: 1,
          lastSeenLabel: '21:14 UTC',
          freshnessLabel: 'Fresh',
          isStale: false,
          alertCount: 1,
          latestIncidentReference: 'INC-1',
          latestSceneReviewLabel: 'identity match concern',
        ),
        VideoFleetScopeHealthView(
          clientId: 'CLIENT-B',
          siteId: 'SITE-B',
          siteName: 'Beta',
          endpointLabel: '10.0.0.2',
          statusLabel: 'WATCH READY',
          watchLabel: 'SCHEDULED',
          recentEvents: 1,
          lastSeenLabel: '21:16 UTC',
          freshnessLabel: 'Recent',
          isStale: false,
          repeatCount: 2,
        ),
      ]);

      expect(
        sections.actionableLabelFor(VideoFleetWatchActionDrilldown.limited),
        'No incident-backed limited-watch scopes right now',
      );
      expect(
        sections.actionableLabelFor(VideoFleetWatchActionDrilldown.alerts),
        'Incident-backed alert scopes',
      );
      expect(
        sections.watchOnlyLabelFor(VideoFleetWatchActionDrilldown.repeat),
        'Watch scopes with repeat-update actions',
      );
      expect(
        sections.watchOnlyLabelFor(VideoFleetWatchActionDrilldown.limited),
        'No watch-only limited-watch scopes awaiting incident context',
      );
      expect(
        sections.watchOnlyLabelFor(VideoFleetWatchActionDrilldown.alerts),
        'No watch-only alert scopes awaiting incident context',
      );
      expect(
        sections.actionableLabelFor(
          VideoFleetWatchActionDrilldown.flaggedIdentity,
        ),
        'Incident-backed flagged-identity scopes',
      );
      expect(
        sections.watchOnlyLabelFor(
          VideoFleetWatchActionDrilldown.temporaryIdentity,
        ),
        'No watch-only temporary identity scopes awaiting incident context',
      );
      expect(
        sections.watchOnlyLabelFor(
          VideoFleetWatchActionDrilldown.allowlistedIdentity,
        ),
        'No watch-only allowlisted identity scopes awaiting incident context',
      );
    });

    test('derives drilldown-aware prominent latest summaries', () {
      const scope = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'Alpha',
        endpointLabel: '10.0.0.1',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        actionHistory: [
          '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
          '21:12 UTC • Camera 3 • Escalation Candidate • Escalated for urgent review because perimeter activity remained high confidence.',
          '21:11 UTC • Camera 4 • Escalation Candidate • Escalated for urgent review because the vehicle remained in a restricted zone.',
        ],
        suppressedHistory: [
          '21:10 UTC • Camera 5 • Suppressed because the activity remained below the client notification threshold.',
          '21:08 UTC • Camera 6 • Suppressed because the vehicle path stayed outside the secure boundary.',
        ],
        latestEventLabel: 'Vehicle motion',
        latestEventTimeLabel: '21:14 UTC',
      );
      const identityScope = VideoFleetScopeHealthView(
        clientId: 'CLIENT-B',
        siteId: 'SITE-B',
        siteName: 'Beta',
        endpointLabel: '10.0.0.2',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:15 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestFaceMatchId: 'PERSON-44',
        latestFaceConfidence: 91.2,
        latestSceneReviewLabel: 'identity match concern',
      );
      const temporaryIdentityScope = VideoFleetScopeHealthView(
        clientId: 'CLIENT-C',
        siteId: 'SITE-C',
        siteName: 'Gamma',
        endpointLabel: '10.0.0.3',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:16 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestFaceMatchId: 'VISITOR-01',
        latestFaceConfidence: 93.1,
        latestPlateNumber: 'CA777777',
        latestPlateConfidence: 97.4,
        latestSceneReviewLabel: 'known allowed identity',
        latestSceneDecisionSummary:
            'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
      );

      expect(
        prominentLatestTextForWatchAction(
          const VideoFleetScopeHealthView(
            clientId: 'CLIENT-L',
            siteId: 'SITE-L',
            siteName: 'Limited Lane',
            endpointLabel: '10.0.0.9',
            statusLabel: 'LIMITED WATCH',
            watchLabel: 'LIMITED',
            recentEvents: 0,
            lastSeenLabel: 'idle',
            freshnessLabel: 'Idle',
            isStale: false,
            monitoringAvailabilityDetail: 'One remote camera feed is stale.',
          ),
          VideoFleetWatchActionDrilldown.limited,
        ),
        'Limited watch: One remote camera feed is stale.',
      );
      expect(
        prominentLatestTextForWatchAction(
          scope,
          VideoFleetWatchActionDrilldown.escalated,
        ),
        'Recent escalations: 21:12 UTC • Camera 3 • Escalation Candidate • Escalated for urgent review because perimeter activity remained high confidence. (+1 more)',
      );
      expect(
        prominentLatestTextForWatchAction(
          scope,
          VideoFleetWatchActionDrilldown.filtered,
        ),
        'Recent filtered reviews: 21:10 UTC • Camera 5 • Suppressed because the activity remained below the client notification threshold. (+1 more)',
      );
      expect(
        prominentLatestTextForWatchAction(
          scope,
          VideoFleetWatchActionDrilldown.repeat,
        ),
        'Recent action: 21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium. (+2 more)',
      );
      expect(
        prominentLatestTextForWatchAction(
          identityScope,
          VideoFleetWatchActionDrilldown.flaggedIdentity,
        ),
        'Flagged identity: Face PERSON-44 91.2%',
      );
      expect(
        prominentLatestTextForWatchAction(
          temporaryIdentityScope,
          VideoFleetWatchActionDrilldown.temporaryIdentity,
        ),
        'Temporary identity until 2026-03-15 18:00 UTC: Face VISITOR-01 93.1% • Plate CA777777 97.4%',
      );
    });

    test('derives temporary drilldown focus detail with soonest expiry', () {
      const alpha = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'Alpha',
        endpointLabel: '10.0.0.1',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestSceneReviewLabel: 'known allowed identity',
        latestSceneDecisionSummary:
            'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
      );
      const beta = VideoFleetScopeHealthView(
        clientId: 'CLIENT-B',
        siteId: 'SITE-B',
        siteName: 'Beta',
        endpointLabel: '10.0.0.2',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:15 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestSceneReviewLabel: 'known allowed identity',
        latestSceneDecisionSummary:
            'Suppressed because the matched identity has a one-time approval until 2026-03-15 17:45 UTC and the activity remained below the client notification threshold.',
      );

      expect(
        focusDetailForWatchAction(
          const <VideoFleetScopeHealthView>[alpha, beta],
          VideoFleetWatchActionDrilldown.temporaryIdentity,
          referenceUtc: DateTime.utc(2026, 3, 15, 17, 3),
        ),
        'Showing fleet scopes where ONYX matched a one-time approved face or plate. Each scope shows the approval expiry when available. Soonest expiry: Beta Temporary approval expires in 42m. (2026-03-15 17:45 UTC).',
      );
    });

    test('orders temporary identity scopes by nearest expiry', () {
      const alpha = VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'Alpha',
        endpointLabel: '10.0.0.1',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestSceneReviewLabel: 'known allowed identity',
        latestSceneDecisionSummary:
            'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
      );
      const beta = VideoFleetScopeHealthView(
        clientId: 'CLIENT-B',
        siteId: 'SITE-B',
        siteName: 'Beta',
        endpointLabel: '10.0.0.2',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:15 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestSceneReviewLabel: 'known allowed identity',
        latestSceneDecisionSummary:
            'Suppressed because the matched identity has a one-time approval until 2026-03-15 17:45 UTC and the activity remained below the client notification threshold.',
      );

      final ordered = orderFleetScopesForWatchAction(
        const <VideoFleetScopeHealthView>[alpha, beta],
        VideoFleetWatchActionDrilldown.temporaryIdentity,
        referenceUtc: DateTime.utc(2026, 3, 15, 17, 3),
      );

      expect(ordered.map((scope) => scope.siteName).toList(), [
        'Beta',
        'Alpha',
      ]);
    });

    test('exposes semantic identity accent colors', () {
      const temporaryScope = VideoFleetScopeHealthView(
        clientId: 'CLIENT-C',
        siteId: 'SITE-C',
        siteName: 'Gamma',
        endpointLabel: '10.0.0.3',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 1,
        lastSeenLabel: '21:16 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestSceneReviewLabel: 'known allowed identity',
        latestSceneDecisionSummary:
            'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
      );
      expect(
        VideoFleetWatchActionDrilldown.flaggedIdentity.accentColor,
        const Color(0xFFF87171),
      );
      expect(
        VideoFleetWatchActionDrilldown.allowlistedIdentity.accentColor,
        const Color(0xFF86EFAC),
      );
      expect(
        VideoFleetWatchActionDrilldown.flaggedIdentity.focusBannerActionColor,
        const Color(0xFFF87171),
      );
      expect(
        VideoFleetWatchActionDrilldown.temporaryIdentity.accentColor,
        const Color(0xFF60A5FA),
      );
      expect(
        identityPolicyAccentColorForScope(
          temporaryScope,
          referenceUtc: DateTime.utc(2026, 3, 15, 12, 0),
        ),
        const Color(0xFF60A5FA),
      );
      expect(
        identityPolicyAccentColorForScope(
          temporaryScope,
          referenceUtc: DateTime.utc(2026, 3, 15, 15, 30),
        ),
        const Color(0xFFFBBF24),
      );
      expect(
        identityPolicyAccentColorForScope(
          temporaryScope,
          referenceUtc: DateTime.utc(2026, 3, 15, 17, 30),
        ),
        const Color(0xFFF87171),
      );
      expect(
        temporaryIdentityAccentColorForScopes(<VideoFleetScopeHealthView>[
          temporaryScope,
        ], referenceUtc: DateTime.utc(2026, 3, 15, 15, 30)),
        const Color(0xFFFBBF24),
      );
      expect(
        VideoFleetWatchActionDrilldown
            .allowlistedIdentity
            .focusBannerActionColor,
        const Color(0xFF86EFAC),
      );
    });
  });
}
