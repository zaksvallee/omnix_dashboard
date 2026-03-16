import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/execution_denied.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/events/report_generated.dart';
import 'package:omnix_dashboard/domain/events/vehicle_visit_review_recorded.dart';
import 'package:omnix_dashboard/domain/guard/guard_ops_event.dart';

void main() {
  group('MorningSovereignReportService', () {
    test('uses the latest completed 06:00 local shift boundary', () {
      final beforeSix = DateTime(2026, 3, 10, 4, 30);
      final afterSix = DateTime(2026, 3, 10, 8, 10);

      expect(
        MorningSovereignReportService.latestCompletedNightShiftEndLocal(
          beforeSix,
        ),
        DateTime(2026, 3, 9, 6, 0),
      );
      expect(
        MorningSovereignReportService.latestCompletedNightShiftEndLocal(
          afterSix,
        ),
        DateTime(2026, 3, 10, 6, 0),
      );
    });

    test('generates deterministic night-shift metrics and serializes', () {
      final service = const MorningSovereignReportService();
      final report = service.generate(
        nowUtc: DateTime.utc(2026, 3, 10, 8, 0),
        events: [
          DecisionCreated(
            eventId: 'DEC-1',
            sequence: 10,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 9, 22, 10),
            dispatchId: 'DSP-1',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-1',
          ),
          ExecutionDenied(
            eventId: 'DEN-1',
            sequence: 11,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 9, 23, 0),
            dispatchId: 'DSP-1',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-1',
            operatorId: 'OP-1',
            reason: 'PSIRA expired',
          ),
          IntelligenceReceived(
            eventId: 'INT-1',
            sequence: 12,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 0, 30),
            intelligenceId: 'INT-1',
            provider: 'feed',
            sourceType: 'news',
            externalId: 'EXT-1',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-2',
            headline: 'Alert',
            summary: 'Summary',
            riskScore: 88,
            canonicalHash: 'hash',
          ),
          IntelligenceReceived(
            eventId: 'INT-2',
            sequence: 13,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 1, 10),
            intelligenceId: 'INT-2',
            provider: 'feed',
            sourceType: 'dvr',
            externalId: 'EXT-2',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-2',
            headline: 'Routine vehicle movement',
            summary: 'Routine vehicle movement.',
            riskScore: 21,
            canonicalHash: 'hash-2',
            cameraId: 'channel-2',
            objectLabel: 'vehicle',
            plateNumber: 'CA 123 456',
            zone: 'Entry Lane',
          ),
          IntelligenceReceived(
            eventId: 'INT-3',
            sequence: 14,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 0, 12),
            intelligenceId: 'INT-3',
            provider: 'feed',
            sourceType: 'dvr',
            externalId: 'EXT-3',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-1',
            headline: 'Repeat person movement',
            summary: 'Repeat person movement detected.',
            riskScore: 58,
            canonicalHash: 'hash-3',
            cameraId: 'channel-1',
          ),
          IntelligenceReceived(
            eventId: 'INT-4',
            sequence: 15,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 1, 25),
            intelligenceId: 'INT-4',
            provider: 'feed',
            sourceType: 'dvr',
            externalId: 'EXT-4',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-2',
            headline: 'Vehicle entered wash bay',
            summary: 'Vehicle moved into wash bay for processing.',
            riskScore: 24,
            canonicalHash: 'hash-4',
            cameraId: 'channel-2',
            objectLabel: 'vehicle',
            plateNumber: 'CA 123 456',
            zone: 'Wash Bay',
          ),
          IntelligenceReceived(
            eventId: 'INT-5',
            sequence: 16,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 1, 40),
            intelligenceId: 'INT-5',
            provider: 'feed',
            sourceType: 'dvr',
            externalId: 'EXT-5',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-2',
            headline: 'Vehicle departed through exit lane',
            summary: 'Vehicle completed service and cleared the exit lane.',
            riskScore: 18,
            canonicalHash: 'hash-5',
            cameraId: 'channel-3',
            objectLabel: 'vehicle',
            plateNumber: 'CA 123 456',
            zone: 'Exit Lane',
          ),
          PartnerDispatchStatusDeclared(
            eventId: 'PARTNER-1',
            sequence: 17,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 1, 45),
            dispatchId: 'DSP-1',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-1',
            partnerLabel: 'Partner Alpha',
            actorLabel: 'controller-1',
            status: PartnerDispatchStatus.accepted,
            sourceChannel: 'telegram',
            sourceMessageKey: 'msg-1',
          ),
          PartnerDispatchStatusDeclared(
            eventId: 'PARTNER-2',
            sequence: 18,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 1, 52),
            dispatchId: 'DSP-1',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-1',
            partnerLabel: 'Partner Alpha',
            actorLabel: 'controller-1',
            status: PartnerDispatchStatus.onSite,
            sourceChannel: 'telegram',
            sourceMessageKey: 'msg-2',
          ),
          ReportGenerated(
            eventId: 'RPT-1',
            sequence: 19,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 2, 20),
            clientId: 'CLIENT-1',
            siteId: 'SITE-2',
            month: '2026-03',
            contentHash: 'content-hash-1',
            pdfHash: 'pdf-hash-1',
            eventRangeStart: 10,
            eventRangeEnd: 18,
            eventCount: 9,
            reportSchemaVersion: 3,
            projectionVersion: 1,
            primaryBrandLabel: 'VISION Tactical',
            endorsementLine: 'Powered by ONYX',
            brandingSourceLabel: 'Partner Alpha',
            brandingUsesOverride: true,
            investigationContextKey: 'governance_branding_drift',
            includeAiDecisionLog: false,
            includeGuardMetrics: false,
          ),
          ReportGenerated(
            eventId: 'RPT-2',
            sequence: 20,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 2, 40),
            clientId: 'CLIENT-1',
            siteId: 'SITE-1',
            month: '2026-03',
            contentHash: 'content-hash-2',
            pdfHash: 'pdf-hash-2',
            eventRangeStart: 10,
            eventRangeEnd: 19,
            eventCount: 10,
            reportSchemaVersion: 1,
            projectionVersion: 1,
          ),
        ],
        recentMedia: [
          GuardOpsMediaUpload(
            mediaId: 'MEDIA-1',
            eventId: 'EVT-1',
            guardId: 'GUARD-1',
            siteId: 'SITE-1',
            shiftId: 'SHIFT-1',
            bucket: 'guard-patrol-images',
            path: 'guards/GUARD-1/patrol/1.jpg',
            localPath: '/tmp/1.jpg',
            capturedAt: DateTime.utc(2026, 3, 10, 1, 0),
            status: GuardMediaUploadStatus.failed,
            visualNorm: const GuardVisualNormMetadata(
              mode: GuardVisualNormMode.night,
              baselineId: 'NORM-PATROL-1',
              captureProfile: 'patrol_verification',
              minMatchScore: 86,
              irRequired: false,
              combatWindow: true,
            ),
          ),
        ],
        guardOutcomePolicyDenied24h: 2,
        sceneReviewByIntelligenceId: {
          'INT-1': MonitoringSceneReviewRecord(
            intelligenceId: 'INT-1',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'escalation candidate',
            decisionLabel: 'Escalation Candidate',
            summary: 'Person visible near the boundary line.',
            reviewedAtUtc: DateTime.utc(2026, 3, 10, 0, 31),
          ),
          'INT-2': MonitoringSceneReviewRecord(
            intelligenceId: 'INT-2',
            sourceLabel: 'metadata:fallback',
            postureLabel: 'reviewed',
            decisionLabel: 'Suppressed Review',
            decisionSummary: 'Vehicle remained below escalation threshold.',
            summary: 'Routine vehicle motion remained internal.',
            reviewedAtUtc: DateTime.utc(2026, 3, 10, 1, 11),
          ),
          'INT-3': MonitoringSceneReviewRecord(
            intelligenceId: 'INT-3',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'repeat activity',
            decisionLabel: 'Repeat Activity',
            decisionSummary:
                'Repeat activity update sent because person movement returned on the same camera.',
            summary: 'Person movement returned on Camera 1.',
            reviewedAtUtc: DateTime.utc(2026, 3, 10, 0, 13),
          ),
        },
      );

      final expectedWindowEndLocal = DateTime(2026, 3, 10, 6, 0);
      final expectedWindowStartUtc = expectedWindowEndLocal
          .subtract(const Duration(hours: 8))
          .toUtc();
      final expectedWindowEndUtc = expectedWindowEndLocal.toUtc();

      expect(report.date, '2026-03-10');
      expect(report.shiftWindowStartUtc, expectedWindowStartUtc);
      expect(report.shiftWindowEndUtc, expectedWindowEndUtc);
      expect(report.ledgerIntegrity.totalEvents, 11);
      expect(report.ledgerIntegrity.hashVerified, isTrue);
      expect(report.aiHumanDelta.aiDecisions, 1);
      expect(report.aiHumanDelta.humanOverrides, 1);
      expect(report.aiHumanDelta.overrideReasons['PSIRA expired'], 1);
      expect(report.normDrift.sitesMonitored, 2);
      expect(report.normDrift.driftDetected, 1);
      expect(report.complianceBlockage.psiraExpired, 1);
      expect(report.complianceBlockage.totalBlocked, 3);
      expect(report.sceneReview.totalReviews, 3);
      expect(report.sceneReview.modelReviews, 2);
      expect(report.sceneReview.metadataFallbackReviews, 1);
      expect(report.sceneReview.suppressedActions, 1);
      expect(report.sceneReview.incidentAlerts, 0);
      expect(report.sceneReview.repeatUpdates, 1);
      expect(report.sceneReview.escalationCandidates, 1);
      expect(report.sceneReview.topPosture, 'escalation candidate');
      expect(
        report.sceneReview.actionMixSummary,
        '1 repeat update • 1 escalation • 1 suppressed review',
      );
      expect(
        report.sceneReview.latestActionTaken,
        '2026-03-10T00:30:00.000Z • Unspecified • Escalation Candidate • Person visible near the boundary line.',
      );
      expect(
        report.sceneReview.recentActionsSummary,
        '2026-03-10T00:30:00.000Z • Unspecified • Escalation Candidate • Person visible near the boundary line. (+1 more)',
      );
      expect(
        report.sceneReview.latestSuppressedPattern,
        '2026-03-10T01:10:00.000Z • Camera 2 • Vehicle remained below escalation threshold.',
      );
      expect(report.receiptPolicy.generatedReports, 2);
      expect(report.receiptPolicy.trackedConfigurationReports, 1);
      expect(report.receiptPolicy.legacyConfigurationReports, 1);
      expect(report.receiptPolicy.fullyIncludedReports, 0);
      expect(report.receiptPolicy.reportsWithOmittedSections, 1);
      expect(report.receiptPolicy.omittedAiDecisionLogReports, 1);
      expect(report.receiptPolicy.omittedGuardMetricsReports, 1);
      expect(report.receiptPolicy.standardBrandingReports, 1);
      expect(report.receiptPolicy.defaultPartnerBrandingReports, 0);
      expect(report.receiptPolicy.customBrandingOverrideReports, 1);
      expect(report.receiptPolicy.governanceHandoffReports, 1);
      expect(report.receiptPolicy.routineReviewReports, 1);
      expect(
        report.receiptPolicy.executiveSummary,
        '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy',
      );
      expect(
        report.receiptPolicy.headline,
        '1 generated reports omitted sections',
      );
      expect(
        report.receiptPolicy.summaryLine,
        'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1 • Standard branding 1 • Default partner branding 0 • Custom branding 1',
      );
      expect(
        report.receiptPolicy.latestReportSummary,
        'CLIENT-1/SITE-1 2026-03 used legacy receipt configuration.',
      );
      expect(
        report.receiptPolicy.brandingExecutiveSummary,
        '1 receipt used custom branding override',
      );
      expect(
        report.receiptPolicy.investigationExecutiveSummary,
        '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
      );
      expect(
        report.receiptPolicy.latestBrandingSummary,
        'CLIENT-1/SITE-1 2026-03 used standard ONYX branding.',
      );
      expect(
        report.receiptPolicy.latestInvestigationSummary,
        'CLIENT-1/SITE-1 2026-03 remained routine report review.',
      );
      expect(report.siteActivity.totalSignals, 4);
      expect(report.siteActivity.personSignals, 0);
      expect(report.siteActivity.vehicleSignals, 3);
      expect(report.siteActivity.knownIdentitySignals, 3);
      expect(report.siteActivity.unknownSignals, 0);
      expect(report.siteActivity.longPresenceSignals, 0);
      expect(report.siteActivity.guardInteractionSignals, 0);
      expect(
        report.siteActivity.executiveSummary,
        '3 vehicle signals • 3 known identity hits',
      );
      expect(
        report.siteActivity.headline,
        '4 site-activity signals recorded',
      );
      expect(
        report.siteActivity.summaryLine,
        'Signals 4 • Vehicles 3 • Known IDs 3',
      );
      expect(report.vehicleThroughput.totalVisits, 1);
      expect(report.vehicleThroughput.completedVisits, 1);
      expect(report.vehicleThroughput.uniqueVehicles, 1);
      expect(report.vehicleThroughput.peakHourLabel, '01:00-02:00');
      expect(report.vehicleThroughput.peakHourVisitCount, 1);
      expect(report.vehicleThroughput.averageCompletedDwellMinutes, 30);
      expect(report.vehicleThroughput.scopeBreakdowns, hasLength(1));
      expect(
        report.vehicleThroughput.scopeBreakdowns.first.clientId,
        'CLIENT-1',
      );
      expect(report.vehicleThroughput.scopeBreakdowns.first.siteId, 'SITE-2');
      expect(report.vehicleThroughput.scopeBreakdowns.first.totalVisits, 1);
      expect(report.vehicleThroughput.exceptionVisits, hasLength(1));
      expect(
        report.vehicleThroughput.exceptionVisits.first.reasonLabel,
        'Loitering visit',
      );
      expect(
        report.vehicleThroughput.exceptionVisits.first.workflowSummary,
        'ENTRY -> SERVICE -> EXIT (COMPLETED)',
      );
      expect(
        report.vehicleThroughput.workflowHeadline,
        '1 completed visit reached EXIT',
      );
      expect(
        report.vehicleThroughput.exceptionVisits.first.primaryEventId,
        'INT-5',
      );
      expect(
        report.vehicleThroughput.exceptionVisits.first.vehicleLabel,
        'CA123456',
      );
      expect(
        report.vehicleThroughput.summaryLine,
        'Visits 1 • Entry 1 • Completed 1 • Active 0 • Incomplete 0 • Unique 1 • Avg dwell 30.0m • Peak 01:00-02:00 (1) • Loitering 1',
      );
      expect(report.partnerProgression.dispatchCount, 1);
      expect(report.partnerProgression.declarationCount, 2);
      expect(report.partnerProgression.acceptedCount, 1);
      expect(report.partnerProgression.onSiteCount, 1);
      expect(report.partnerProgression.allClearCount, 0);
      expect(
        report.partnerProgression.workflowHeadline,
        '1 partner dispatch remains ON SITE',
      );
      expect(report.partnerProgression.performanceHeadline, '1 watch response');
      expect(
        report.partnerProgression.slaHeadline,
        'Avg accept 215.0m • Avg on site 222.0m',
      );
      expect(
        report.partnerProgression.summaryLine,
        'Dispatches 1 • Declarations 2 • Accept 1 • On site 1 • All clear 0 • Cancelled 0',
      );
      expect(report.partnerProgression.scopeBreakdowns, hasLength(1));
      expect(report.partnerProgression.scoreboardRows, hasLength(1));
      expect(report.partnerProgression.dispatchChains, hasLength(1));
      expect(
        report.partnerProgression.scoreboardRows.first.partnerLabel,
        'Partner Alpha',
      );
      expect(report.partnerProgression.scoreboardRows.first.watchCount, 1);
      expect(
        report.partnerProgression.scoreboardRows.first.summaryLine,
        'Dispatches 1 • Strong 0 • On track 0 • Watch 1 • Critical 0 • Avg accept 215.0m • Avg on site 222.0m',
      );
      expect(
        report.partnerProgression.dispatchChains.first.workflowSummary,
        'ACCEPT -> ON SITE (LATEST ON SITE)',
      );
      expect(
        report.partnerProgression.dispatchChains.first.scoreLabel,
        'WATCH',
      );
      expect(
        report.partnerProgression.dispatchChains.first.scoreReason,
        'Partner is on site, but the approach timing drifted beyond target windows.',
      );
      expect(
        report.partnerProgression.dispatchChains.first.acceptedDelayMinutes,
        215.0,
      );
      expect(
        report.partnerProgression.dispatchChains.first.onSiteDelayMinutes,
        222.0,
      );

      final restored = SovereignReport.fromJson(report.toJson());
      expect(restored.date, report.date);
      expect(restored.ledgerIntegrity.totalEvents, 11);
      expect(restored.aiHumanDelta.humanOverrides, 1);
      expect(restored.sceneReview.totalReviews, 3);
      expect(restored.receiptPolicy.generatedReports, 2);
      expect(
        restored.receiptPolicy.executiveSummary,
        report.receiptPolicy.executiveSummary,
      );
      expect(restored.receiptPolicy.headline, report.receiptPolicy.headline);
      expect(
        restored.receiptPolicy.latestReportSummary,
        report.receiptPolicy.latestReportSummary,
      );
      expect(
        restored.receiptPolicy.brandingExecutiveSummary,
        report.receiptPolicy.brandingExecutiveSummary,
      );
      expect(
        restored.receiptPolicy.investigationExecutiveSummary,
        report.receiptPolicy.investigationExecutiveSummary,
      );
      expect(
        restored.receiptPolicy.latestBrandingSummary,
        report.receiptPolicy.latestBrandingSummary,
      );
      expect(
        restored.receiptPolicy.latestInvestigationSummary,
        report.receiptPolicy.latestInvestigationSummary,
      );
      expect(restored.siteActivity.totalSignals, 4);
      expect(
        restored.siteActivity.executiveSummary,
        report.siteActivity.executiveSummary,
      );
      expect(restored.siteActivity.headline, report.siteActivity.headline);
      expect(restored.siteActivity.summaryLine, report.siteActivity.summaryLine);
      expect(restored.sceneReview.escalationCandidates, 1);
      expect(
        restored.sceneReview.actionMixSummary,
        report.sceneReview.actionMixSummary,
      );
      expect(
        restored.sceneReview.latestActionTaken,
        report.sceneReview.latestActionTaken,
      );
      expect(
        restored.sceneReview.recentActionsSummary,
        report.sceneReview.recentActionsSummary,
      );
      expect(
        restored.sceneReview.latestSuppressedPattern,
        report.sceneReview.latestSuppressedPattern,
      );
      expect(
        restored.vehicleThroughput.summaryLine,
        report.vehicleThroughput.summaryLine,
      );
      expect(restored.vehicleThroughput.scopeBreakdowns, hasLength(1));
      expect(restored.vehicleThroughput.exceptionVisits, hasLength(1));
      expect(
        restored.vehicleThroughput.exceptionVisits.first.workflowSummary,
        'ENTRY -> SERVICE -> EXIT (COMPLETED)',
      );
      expect(
        restored.vehicleThroughput.workflowHeadline,
        '1 completed visit reached EXIT',
      );
      expect(restored.partnerProgression.dispatchCount, 1);
      expect(restored.partnerProgression.scopeBreakdowns, hasLength(1));
      expect(restored.partnerProgression.scoreboardRows, hasLength(1));
      expect(restored.partnerProgression.dispatchChains, hasLength(1));
      expect(
        restored.partnerProgression.performanceHeadline,
        '1 watch response',
      );
      expect(
        restored.partnerProgression.slaHeadline,
        'Avg accept 215.0m • Avg on site 222.0m',
      );
      expect(
        restored.partnerProgression.dispatchChains.first.workflowSummary,
        'ACCEPT -> ON SITE (LATEST ON SITE)',
      );
    });

    test(
      'applies latest vehicle visit review events to throughput exceptions',
      () {
        final service = const MorningSovereignReportService();
        final report = service.generate(
          nowUtc: DateTime.utc(2026, 3, 10, 8, 30),
          events: [
            IntelligenceReceived(
              eventId: 'INT-ENTRY',
              sequence: 20,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 10, 0, 10),
              intelligenceId: 'INT-ENTRY',
              provider: 'feed',
              sourceType: 'dvr',
              externalId: 'EXT-ENTRY',
              clientId: 'CLIENT-9',
              regionId: 'REGION-9',
              siteId: 'SITE-9',
              headline: 'Vehicle entered entry lane',
              summary: 'Vehicle entered the monitored lane.',
              riskScore: 22,
              canonicalHash: 'hash-entry',
              cameraId: 'lane-1',
              objectLabel: 'vehicle',
              plateNumber: 'ND 987 654',
              zone: 'Entry Lane',
            ),
            IntelligenceReceived(
              eventId: 'INT-SERVICE',
              sequence: 21,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 10, 0, 24),
              intelligenceId: 'INT-SERVICE',
              provider: 'feed',
              sourceType: 'dvr',
              externalId: 'EXT-SERVICE',
              clientId: 'CLIENT-9',
              regionId: 'REGION-9',
              siteId: 'SITE-9',
              headline: 'Vehicle entered wash bay',
              summary: 'Vehicle moved into the service zone.',
              riskScore: 18,
              canonicalHash: 'hash-service',
              cameraId: 'lane-2',
              objectLabel: 'vehicle',
              plateNumber: 'ND 987 654',
              zone: 'Wash Bay',
            ),
            VehicleVisitReviewRecorded(
              eventId: 'VR-1',
              sequence: 22,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 10, 8, 5),
              vehicleVisitKey: 'INT-SERVICE',
              primaryEventId: 'INT-SERVICE',
              clientId: 'CLIENT-9',
              regionId: 'REGION-9',
              siteId: 'SITE-9',
              vehicleLabel: 'ND987654',
              actorLabel: 'GOVERNANCE_OPERATOR',
              reviewed: true,
              statusOverride: 'COMPLETED',
              effectiveStatusLabel: 'COMPLETED',
              reasonLabel: 'Incomplete visit',
              workflowSummary: 'ENTRY -> SERVICE (COMPLETED)',
              sourceSurface: 'governance',
            ),
          ],
          recentMedia: const [],
          guardOutcomePolicyDenied24h: 0,
          sceneReviewByIntelligenceId: const {},
        );

        expect(report.vehicleThroughput.exceptionVisits, hasLength(1));
        final exception = report.vehicleThroughput.exceptionVisits.single;
        expect(exception.primaryEventId, 'INT-SERVICE');
        expect(exception.statusLabel, 'COMPLETED');
        expect(exception.workflowSummary, 'ENTRY -> SERVICE (COMPLETED)');
        expect(exception.operatorReviewed, isTrue);
        expect(exception.operatorStatusOverride, 'COMPLETED');
        expect(
          exception.operatorReviewedAtUtc,
          DateTime.utc(2026, 3, 10, 8, 5),
        );
      },
    );
  });
}
