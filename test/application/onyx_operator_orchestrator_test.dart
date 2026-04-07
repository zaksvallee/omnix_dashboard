import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/onyx_operator_orchestrator.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

void main() {
  const orchestrator = OnyxOperatorOrchestrator();

  OnyxWorkItem buildItem({
    String prompt =
        'Triage the active incident and stage one obvious next move',
    DateTime? createdAt,
    DateTime? latestEventAt,
    int totalScopedEvents = 0,
    int activeDispatchCount = 0,
    int dispatchesAwaitingResponseCount = 0,
    int responseCount = 0,
    int closedDispatchCount = 0,
    int patrolCount = 0,
    int guardCheckInCount = 0,
    int scopedSiteCount = 0,
    bool hasVisualSignal = false,
    String latestIntelligenceHeadline = '',
    int? latestIntelligenceRiskScore,
    String latestPartnerStatusLabel = '',
    String latestEventLabel = '',
    String contextSummary = '',
    DateTime? latestDispatchCreatedAt,
    DateTime? latestClosureAt,
    String prioritySiteLabel = '',
    String prioritySiteReason = '',
    int? prioritySiteRiskScore,
    List<String> rankedSiteSummaries = const <String>[],
    int repeatedFalseAlarmCount = 0,
    bool hasHumanSafetySignal = false,
    bool hasGuardWelfareRisk = false,
    String guardWelfareSignalLabel = '',
    String pendingFollowUpLabel = '',
    String pendingFollowUpPrompt = '',
    OnyxToolTarget? pendingFollowUpTarget,
    int pendingFollowUpAgeMinutes = 0,
    int staleFollowUpSurfaceCount = 0,
    List<String> pendingConfirmations = const <String>[],
  }) {
    return OnyxWorkItem(
      id: 'work-item-1',
      intent: OnyxWorkIntent.triageIncident,
      prompt: prompt,
      clientId: 'CLIENT-001',
      siteId: 'SITE-SANDTON',
      incidentReference: 'INC-42',
      sourceRouteLabel: 'Command',
      createdAt: createdAt ?? DateTime.utc(2026, 3, 31, 8, 0),
      contextSummary: contextSummary,
      totalScopedEvents: totalScopedEvents,
      activeDispatchCount: activeDispatchCount,
      dispatchesAwaitingResponseCount: dispatchesAwaitingResponseCount,
      responseCount: responseCount,
      closedDispatchCount: closedDispatchCount,
      patrolCount: patrolCount,
      guardCheckInCount: guardCheckInCount,
      scopedSiteCount: scopedSiteCount,
      hasVisualSignal: hasVisualSignal,
      latestIntelligenceHeadline: latestIntelligenceHeadline,
      latestIntelligenceRiskScore: latestIntelligenceRiskScore,
      latestPartnerStatusLabel: latestPartnerStatusLabel,
      latestEventLabel: latestEventLabel,
      latestEventAt: latestEventAt,
      latestDispatchCreatedAt: latestDispatchCreatedAt,
      latestClosureAt: latestClosureAt,
      prioritySiteLabel: prioritySiteLabel,
      prioritySiteReason: prioritySiteReason,
      prioritySiteRiskScore: prioritySiteRiskScore,
      rankedSiteSummaries: rankedSiteSummaries,
      repeatedFalseAlarmCount: repeatedFalseAlarmCount,
      hasHumanSafetySignal: hasHumanSafetySignal,
      hasGuardWelfareRisk: hasGuardWelfareRisk,
      guardWelfareSignalLabel: guardWelfareSignalLabel,
      pendingFollowUpLabel: pendingFollowUpLabel,
      pendingFollowUpPrompt: pendingFollowUpPrompt,
      pendingFollowUpTarget: pendingFollowUpTarget,
      pendingFollowUpAgeMinutes: pendingFollowUpAgeMinutes,
      staleFollowUpSurfaceCount: staleFollowUpSurfaceCount,
      pendingConfirmations: pendingConfirmations,
    );
  }

  test('defaults to Dispatch Board when no richer context is available', () {
    final recommendation = orchestrator.recommend(buildItem());

    expect(recommendation.target, OnyxToolTarget.dispatchBoard);
    expect(
      recommendation.summary,
      'One next move is staged in Dispatch Board.',
    );
  });

  test('prefers Tactical Track when field movement is already live', () {
    final recommendation = orchestrator.recommend(
      buildItem(
        responseCount: 1,
        patrolCount: 1,
        contextSummary: 'Responses moving: 1. Patrol completions: 1.',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.tacticalTrack);
    expect(
      recommendation.detail,
      contains('Field movement is already underway'),
    );
  });

  test('prefers CCTV Review when the strongest context is visual evidence', () {
    final recommendation = orchestrator.recommend(
      buildItem(
        hasVisualSignal: true,
        latestIntelligenceHeadline: 'Suspicious vehicle circling gate',
        latestIntelligenceRiskScore: 87,
        contextSummary:
            'Latest visual signal: Suspicious vehicle circling gate (risk 87).',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.cctvReview);
    expect(recommendation.detail, contains('Suspicious vehicle circling gate'));
  });

  test('suppresses repeated false-alarm motion instead of escalating', () {
    final recommendation = orchestrator.recommend(
      buildItem(
        prompt: 'Is this a breach?',
        totalScopedEvents: 5,
        hasVisualSignal: true,
        latestIntelligenceHeadline: 'Tree motion across the west fence line',
        latestIntelligenceRiskScore: 18,
        repeatedFalseAlarmCount: 5,
        contextSummary:
            'Repeated tree motion pattern matched across five prior false alarms.',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.cctvReview);
    expect(recommendation.advisory, 'Repeated false pattern detected.');
    expect(recommendation.confidence, greaterThanOrEqualTo(0.75));
    expect(
      recommendation.missingInfo,
      contains('fresh human confirmation if the scene changes'),
    );
  });

  test('resists client pressure when no verified threat is loaded', () {
    final recommendation = orchestrator.recommend(
      buildItem(
        prompt: 'Client wants immediate dispatch',
        contextSummary:
            'Client anxiety is high but no live threat is verified.',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.clientComms);
    expect(
      recommendation.advisory,
      'No verified threat is loaded in the scoped context.',
    );
    expect(recommendation.confidence, greaterThanOrEqualTo(0.8));
    expect(recommendation.detail, contains('factual reassurance update'));
    expect(recommendation.missingInfo, contains('verified threat signal'));
  });

  test('prioritizes human safety when guard risk conflicts with quiet CCTV', () {
    final recommendation = orchestrator.recommend(
      buildItem(
        prompt: "What's happening?",
        totalScopedEvents: 2,
        hasHumanSafetySignal: true,
        contextSummary:
            'Guard panic signal triggered while the nearest camera still appears quiet.',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.dispatchBoard);
    expect(
      recommendation.advisory,
      'Human safety signal takes priority over the visual contradiction.',
    );
    expect(recommendation.confidence, greaterThanOrEqualTo(0.9));
    expect(recommendation.detail, contains('human safety signal'));
    expect(
      recommendation.missingInfo,
      contains('guard voice or welfare confirmation'),
    );
  });

  test('holds for clarification when a threat query has no signals', () {
    final recommendation = orchestrator.recommend(
      buildItem(prompt: 'Is there a fire?'),
    );

    expect(recommendation.allowRouteExecution, isFalse);
    expect(
      recommendation.summary,
      'Clarification is staged before ONYX reopens a desk.',
    );
    expect(
      recommendation.advisory,
      'No signals detected for that threat in the current scoped context.',
    );
    expect(recommendation.confidence, lessThan(0.3));
    expect(recommendation.missingInfo, contains('site or incident reference'));
  });

  test('detects delayed response when eta has stretched without arrival', () {
    final createdAt = DateTime.utc(2026, 3, 31, 8, 20);
    final recommendation = orchestrator.recommend(
      buildItem(
        prompt: 'Status?',
        createdAt: createdAt,
        latestDispatchCreatedAt: createdAt.subtract(
          const Duration(minutes: 18),
        ),
        latestEventAt: createdAt.subtract(const Duration(minutes: 3)),
        activeDispatchCount: 1,
        dispatchesAwaitingResponseCount: 1,
        contextSummary:
            'Dispatch triggered. ETA exceeded. No arrival event has landed.',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.dispatchBoard);
    expect(recommendation.advisory, 'Response delay detected.');
    expect(recommendation.confidence, greaterThanOrEqualTo(0.85));
    expect(recommendation.followUpLabel, 'RECHECK RESPONDER ETA');
    expect(recommendation.contextHighlights.single, contains('18 minutes'));
    expect(recommendation.missingInfo, contains('current responder ETA'));
  });

  test('treats site-okay prompts as status prompts for delayed responses', () {
    final createdAt = DateTime.utc(2026, 3, 31, 8, 20);
    final recommendation = orchestrator.recommend(
      buildItem(
        prompt: 'Is the site okay?',
        createdAt: createdAt,
        latestDispatchCreatedAt: createdAt.subtract(
          const Duration(minutes: 18),
        ),
        latestEventAt: createdAt.subtract(const Duration(minutes: 3)),
        activeDispatchCount: 1,
        dispatchesAwaitingResponseCount: 1,
        contextSummary:
            'Dispatch triggered. ETA exceeded. No arrival event has landed.',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.dispatchBoard);
    expect(recommendation.advisory, 'Response delay detected.');
    expect(recommendation.followUpLabel, 'RECHECK RESPONDER ETA');
  });

  test(
    'treats current-view, movement, and issue prompts as status prompts for delayed responses',
    () {
      const prompts = <String>[
        'What is happening now?',
        'Is there any movement detected?',
        'Is there any issue on site?',
      ];

      for (final prompt in prompts) {
        final createdAt = DateTime.utc(2026, 3, 31, 8, 20);
        final recommendation = orchestrator.recommend(
          buildItem(
            prompt: prompt,
            createdAt: createdAt,
            latestDispatchCreatedAt: createdAt.subtract(
              const Duration(minutes: 18),
            ),
            latestEventAt: createdAt.subtract(const Duration(minutes: 3)),
            activeDispatchCount: 1,
            dispatchesAwaitingResponseCount: 1,
            contextSummary:
                'Dispatch triggered. ETA exceeded. No arrival event has landed.',
          ),
        );

        expect(recommendation.target, OnyxToolTarget.dispatchBoard);
        expect(recommendation.advisory, 'Response delay detected.');
        expect(recommendation.followUpLabel, 'RECHECK RESPONDER ETA');
      }
    },
  );

  test(
    'prioritizes an overdue pending follow-up during generic next-step triage',
    () {
      final recommendation = orchestrator.recommend(
        buildItem(
          prompt: 'What should I do next?',
          pendingFollowUpLabel: 'RECHECK RESPONDER ETA',
          pendingFollowUpPrompt:
              'Status? Recheck the delayed response for INC-42.',
          pendingFollowUpTarget: OnyxToolTarget.dispatchBoard,
          pendingFollowUpAgeMinutes: 26,
          staleFollowUpSurfaceCount: 2,
          pendingConfirmations: const <String>[
            'current responder ETA',
            'follow-up acknowledgment from dispatch partner',
          ],
        ),
      );

      expect(recommendation.target, OnyxToolTarget.dispatchBoard);
      expect(recommendation.advisory, 'Outstanding follow-up is overdue.');
      expect(recommendation.followUpLabel, 'RECHECK RESPONDER ETA');
      expect(
        recommendation.contextHighlights.first,
        'Outstanding follow-up: RECHECK RESPONDER ETA',
      );
      expect(recommendation.missingInfo, contains('current responder ETA'));
      expect(recommendation.confidence, greaterThanOrEqualTo(0.86));
    },
  );

  test('keeps recent closures in reporting mode instead of reopening', () {
    final createdAt = DateTime.utc(2026, 3, 31, 8, 20);
    final recommendation = orchestrator.recommend(
      buildItem(
        prompt: 'Is everything okay?',
        createdAt: createdAt,
        latestClosureAt: createdAt.subtract(const Duration(minutes: 2)),
        latestEventAt: createdAt.subtract(const Duration(minutes: 1)),
        closedDispatchCount: 1,
        latestEventLabel: 'Incident closed',
        contextSummary: 'Incident closed two minutes ago with no live reopen.',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.reportsWorkspace);
    expect(recommendation.allowRouteExecution, isFalse);
    expect(recommendation.advisory, 'Incident resolved.');
    expect(
      recommendation.summary,
      'Incident resolved and held in Reports Workspace.',
    );
  });

  test('prioritizes the highest-risk site when triaging across sites', () {
    final recommendation = orchestrator.recommend(
      buildItem(
        prompt: "What's happening across sites?",
        scopedSiteCount: 2,
        prioritySiteLabel: 'SITE-B',
        prioritySiteReason: 'Confirmed breach at the north gate (risk 96)',
        prioritySiteRiskScore: 96,
        rankedSiteSummaries: const <String>[
          '1. SITE-B — Confirmed breach at the north gate (risk 96)',
          '2. SITE-A — Tree motion near the outer fence (risk 19)',
        ],
        contextSummary:
            'Highest-priority site: SITE-B because Confirmed breach at the north gate (risk 96).',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.tacticalTrack);
    expect(recommendation.advisory, 'Prioritize SITE-B first.');
    expect(recommendation.confidence, greaterThanOrEqualTo(0.85));
    expect(recommendation.detail, contains('SITE-B'));
    expect(recommendation.contextHighlights, hasLength(2));
    expect(recommendation.contextHighlights.first, contains('SITE-B'));
    expect(recommendation.followUpLabel, 'RECHECK LOWER-PRIORITY SITES');
    expect(
      recommendation.missingInfo,
      contains('fresh confirmation from lower-priority sites'),
    );
  });

  test('escalates guard welfare distress ahead of quieter visuals', () {
    final recommendation = orchestrator.recommend(
      buildItem(
        prompt: 'Status guard?',
        hasGuardWelfareRisk: true,
        guardWelfareSignalLabel:
            'Guard distress pattern from wearable telemetry',
        contextSummary:
            'Guard welfare signal: Guard distress pattern from wearable telemetry.',
      ),
    );

    expect(recommendation.target, OnyxToolTarget.dispatchBoard);
    expect(recommendation.advisory, 'Possible guard distress detected.');
    expect(recommendation.confidence, greaterThanOrEqualTo(0.88));
    expect(recommendation.detail, contains('welfare escalation'));
    expect(recommendation.followUpLabel, 'VERIFY GUARD WELFARE');
    expect(recommendation.followUpPrompt, contains('fresh wearable telemetry'));
    expect(
      recommendation.missingInfo,
      contains('fresh wearable telemetry sample'),
    );
  });
}
