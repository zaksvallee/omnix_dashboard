import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_action_plan.dart';
import 'package:omnix_dashboard/application/synthetic_promotion_summary_formatter.dart';

void main() {
  group('buildSyntheticPromotionSummary', () {
    test('returns base summary when no urgency context exists', () {
      expect(
        buildSyntheticPromotionSummary(baseSummary: 'Promote MO-1'),
        'Promote MO-1',
      );
    });

    test(
      'adds urgency and posture-bias context when both exist',
      () {
      expect(
        buildSyntheticPromotionSummary(
          baseSummary: 'Promote MO-1',
          shadowTomorrowUrgencySummary: 'strength rising • critical • 22s',
          previousShadowTomorrowUrgencySummary:
              'strength stable • high • 28s',
          shadowPostureBiasSummary: 'POSTURE SURGE • critical • 28s',
        ),
        'Promote MO-1 • pressure strength rising • critical • 22s (prev strength stable • high • 28s) • posture POSTURE SURGE • critical • 28s',
      );
      },
    );
  });

  group('buildSyntheticPromotionDecisionSummary', () {
    test('returns base decision when no urgency context exists', () {
      expect(
        buildSyntheticPromotionDecisionSummary(
          baseSummary: 'Accepted toward validated review.',
        ),
        'Accepted toward validated review.',
      );
    });

    test(
      'adds urgency and posture-bias context when both exist',
      () {
      expect(
        buildSyntheticPromotionDecisionSummary(
          baseSummary: 'Accepted toward validated review.',
          shadowTomorrowUrgencySummary: 'strength rising • critical • 22s',
          previousShadowTomorrowUrgencySummary:
              'strength stable • high • 28s',
          shadowPostureBiasSummary: 'POSTURE SURGE • critical • 28s',
        ),
        'Accepted toward validated review. • under strength rising • critical • 22s pressure (prev strength stable • high • 28s) • posture POSTURE SURGE • critical • 28s',
      );
      },
    );
  });

  group('buildSyntheticPromotionPressureSummary', () {
    test('returns urgency and posture shorthand without base text', () {
      expect(
        buildSyntheticPromotionPressureSummary(
          shadowTomorrowUrgencySummary: 'strength rising • critical • 22s',
          previousShadowTomorrowUrgencySummary:
              'strength stable • high • 28s',
          shadowPostureBiasSummary: 'POSTURE SURGE • critical • 28s',
        ),
        'strength rising • critical • 22s (prev strength stable • high • 28s) • posture POSTURE SURGE • critical • 28s',
      );
    });
  });

  group('plan-aware helpers', () {
    test('buildSyntheticPromotionIdFromPlans and target helper read plan metadata', () {
      final plans = <MonitoringWatchAutonomyActionPlan>[
        const MonitoringWatchAutonomyActionPlan(
          id: 'SIM-1',
          incidentId: 'SITE-1',
          siteId: 'SITE-1',
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'POLICY RECOMMENDATION',
          description: 'desc',
          countdownSeconds: 22,
          metadata: <String, String>{
            'mo_promotion_id': 'MO-1',
            'mo_promotion_target': 'validated',
          },
        ),
      ];

      expect(buildSyntheticPromotionIdFromPlans(plans: plans), 'MO-1');
      expect(
        buildSyntheticPromotionTargetStatusFromPlans(plans: plans),
        'validated',
      );
    });

    test('learning and shadow summary helpers read plan metadata', () {
      final plans = <MonitoringWatchAutonomyActionPlan>[
        const MonitoringWatchAutonomyActionPlan(
          id: 'SIM-1',
          incidentId: 'SITE-1',
          siteId: 'SITE-1',
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'POLICY RECOMMENDATION',
          description: 'desc',
          countdownSeconds: 22,
          metadata: <String, String>{
            'learning_label': 'HARDEN ACCESS EARLIER',
            'learning_summary': 'Learned bias: start checks sooner.',
            'shadow_learning_summary': 'Shadow lesson: watch contractor drift.',
            'shadow_memory_summary': 'Shadow bias: HARDEN ACCESS',
          },
        ),
      ];

      expect(
        buildSyntheticLearningLabelFromPlans(plans: plans),
        'HARDEN ACCESS EARLIER',
      );
      expect(
        buildSyntheticLearningSummaryFromPlans(plans: plans),
        'Learned bias: start checks sooner.',
      );
      expect(
        buildSyntheticShadowLearningSummaryFromPlans(plans: plans),
        'Shadow lesson: watch contractor drift.',
      );
      expect(
        buildSyntheticShadowMemorySummaryFromPlans(plans: plans),
        'Shadow bias: HARDEN ACCESS',
      );
      expect(
        buildSyntheticShadowSummaryFromPlans(plans: plans),
        '',
      );
    });

    test('buildSyntheticShadowSummaryFromPlans reads shadow label context', () {
      final plans = <MonitoringWatchAutonomyActionPlan>[
        const MonitoringWatchAutonomyActionPlan(
          id: 'SIM-1',
          incidentId: 'SITE-1',
          siteId: 'SITE-1',
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'POLICY RECOMMENDATION',
          description: 'desc',
          countdownSeconds: 22,
          metadata: <String, String>{
            'lead_site': 'SITE-ALPHA',
            'shadow_mo_label': 'HARDEN ACCESS',
            'shadow_mo_title': 'Office contractor roaming',
            'shadow_mo_repeat_count': '2',
          },
        ),
      ];

      expect(
        buildSyntheticShadowSummaryFromPlans(plans: plans),
        'HARDEN ACCESS • SITE-ALPHA • Office contractor roaming • x2',
      );
    });

    test('buildSyntheticPromotionSummaryFromPlans reads base summary from plan metadata', () {
      final plans = <MonitoringWatchAutonomyActionPlan>[
        const MonitoringWatchAutonomyActionPlan(
          id: 'SIM-1',
          incidentId: 'SITE-1',
          siteId: 'SITE-1',
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'POLICY RECOMMENDATION',
          description: 'desc',
          countdownSeconds: 22,
          metadata: <String, String>{'mo_promotion_summary': 'Promote MO-1'},
        ),
      ];

      expect(
        buildSyntheticPromotionSummaryFromPlans(
          plans: plans,
          shadowTomorrowUrgencySummary: 'strength rising • critical • 22s',
        ),
        'Promote MO-1 • pressure strength rising • critical • 22s',
      );
    });

    test('buildSyntheticPromotionPressureSummaryFromPlans prefers prebuilt metadata', () {
      final plans = <MonitoringWatchAutonomyActionPlan>[
        const MonitoringWatchAutonomyActionPlan(
          id: 'SIM-1',
          incidentId: 'SITE-1',
          siteId: 'SITE-1',
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'POLICY RECOMMENDATION',
          description: 'desc',
          countdownSeconds: 22,
          metadata: <String, String>{
            'mo_promotion_pressure_summary': 'Promote MO-1 • posture POSTURE SURGE • critical • 28s',
          },
        ),
      ];

      expect(
        buildSyntheticPromotionPressureSummaryFromPlans(
          plans: plans,
          shadowTomorrowUrgencySummary: 'ignored',
        ),
        'Promote MO-1 • posture POSTURE SURGE • critical • 28s',
      );
    });

    test('buildSyntheticPromotionDecisionSummaryFromPlans reads decision state via lookup', () {
      final plans = <MonitoringWatchAutonomyActionPlan>[
        const MonitoringWatchAutonomyActionPlan(
          id: 'SIM-1',
          incidentId: 'SITE-1',
          siteId: 'SITE-1',
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'POLICY RECOMMENDATION',
          description: 'desc',
          countdownSeconds: 22,
          metadata: <String, String>{
            'mo_promotion_id': 'MO-1',
            'mo_promotion_target': 'validated',
          },
        ),
      ];

      expect(
        buildSyntheticPromotionDecisionSummaryFromPlans(
          plans: plans,
          decisionSummaryLookup: (moId, targetStatus) =>
              'Accepted $moId toward $targetStatus review.',
          shadowTomorrowUrgencySummary: 'strength rising • critical • 22s',
        ),
        'Accepted MO-1 toward validated review. • under strength rising • critical • 22s pressure',
      );
    });

    test('buildSyntheticPromotionDecisionStatusFromPlans reads id via lookup', () {
      final plans = <MonitoringWatchAutonomyActionPlan>[
        const MonitoringWatchAutonomyActionPlan(
          id: 'SIM-1',
          incidentId: 'SITE-1',
          siteId: 'SITE-1',
          priority: MonitoringWatchAutonomyPriority.high,
          actionType: 'POLICY RECOMMENDATION',
          description: 'desc',
          countdownSeconds: 22,
          metadata: <String, String>{'mo_promotion_id': 'MO-1'},
        ),
      ];

      expect(
        buildSyntheticPromotionDecisionStatusFromPlans(
          plans: plans,
          decisionStatusLookup: (moId) => moId == 'MO-1' ? 'accepted' : '',
        ),
        'accepted',
      );
    });

    test('buildSyntheticShadowPostureBiasSummaryForPlan prefers prebuilt summary', () {
      const plan = MonitoringWatchAutonomyActionPlan(
        id: 'SIM-1',
        incidentId: 'SITE-1',
        siteId: 'SITE-1',
        priority: MonitoringWatchAutonomyPriority.high,
        actionType: 'POLICY RECOMMENDATION',
        description: 'desc',
        countdownSeconds: 22,
        metadata: <String, String>{
          'shadow_posture_bias_summary': 'POSTURE SURGE • CRITICAL • 28s',
        },
      );

      expect(
        buildSyntheticShadowPostureBiasSummaryForPlan(plan: plan),
        'POSTURE SURGE • CRITICAL • 28s',
      );
    });
  });
}
