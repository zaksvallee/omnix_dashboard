import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/guard/guard_ops_event.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/ui/dashboard_page.dart';

void main() {
  testWidgets('dashboard stays stable on phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(eventStore: InMemoryEventStore())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Command Dashboard'), findsOneWidget);
    expect(find.text('KPI Band'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(eventStore: InMemoryEventStore())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Command Dashboard'), findsOneWidget);
    expect(find.text('KPI Band'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard guard sync card shows alert badges and opens guard sync', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var openCount = 0;
    var clearPolicyCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: InMemoryEventStore(),
          guardSyncBackendEnabled: false,
          guardSyncInFlight: false,
          guardSyncQueueDepth: 60,
          guardPendingEvents: 5,
          guardPendingMedia: 2,
          guardFailedEvents: 3,
          guardFailedMedia: 1,
          guardOutcomePolicyDeniedCount: 4,
          guardOutcomePolicyDeniedLastReason:
              'Confirmation role "control" is not allowed for true_threat.',
          guardOutcomePolicyDenied24h: 3,
          guardOutcomePolicyDenied7d: 6,
          guardOutcomePolicyDeniedHistoryUtc: [
            DateTime.now().toUtc().subtract(const Duration(hours: 2)),
            DateTime.now().toUtc().subtract(const Duration(days: 2)),
          ],
          guardCoachingAckCount: 5,
          guardCoachingSnoozeCount: 2,
          guardCoachingSnoozeExpiryCount: 1,
          guardCoachingRecentHistory: const [
            '[2026-03-05T12:10:00.000Z] high_failure_backlog acknowledged @ sync by guard',
            '[2026-03-05T12:20:00.000Z] high_failure_backlog snoozed 10m @ dispatch by supervisor',
          ],
          guardLastSuccessfulSyncAtUtc: DateTime.now().toUtc().subtract(
            const Duration(minutes: 20),
          ),
          guardLastFailureReason: 'network unavailable',
          guardRecentEvents: [
            GuardOpsEvent(
              eventId: 'EVT-1',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.panicTriggered,
              sequence: 44,
              occurredAt: DateTime.now().toUtc(),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {},
              failureReason: 'event sync timeout',
            ),
          ],
          guardRecentMedia: [
            GuardOpsMediaUpload(
              mediaId: 'MEDIA-1',
              eventId: 'EVT-1',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              bucket: 'guard-incident-media',
              path: 'guards/GUARD-001/incident/evidence.jpg',
              localPath: '/tmp/evidence.jpg',
              capturedAt: DateTime.now().toUtc(),
              status: GuardMediaUploadStatus.failed,
              failureReason: 'upload timeout',
            ),
          ],
          morningSovereignReport: SovereignReport(
            date: '2026-03-09',
            generatedAtUtc: DateTime.utc(2026, 3, 9, 6, 0),
            shiftWindowStartUtc: DateTime.utc(2026, 3, 8, 22, 0),
            shiftWindowEndUtc: DateTime.utc(2026, 3, 9, 6, 0),
            ledgerIntegrity: const SovereignReportLedgerIntegrity(
              totalEvents: 42,
              hashVerified: true,
              integrityScore: 100,
            ),
            aiHumanDelta: const SovereignReportAiHumanDelta(
              aiDecisions: 12,
              humanOverrides: 3,
              overrideReasons: {'HARDWARE_FAULT': 2, 'FALSE_ALARM': 1},
            ),
            normDrift: const SovereignReportNormDrift(
              sitesMonitored: 4,
              driftDetected: 1,
              avgMatchScore: 87.5,
            ),
            complianceBlockage: const SovereignReportComplianceBlockage(
              psiraExpired: 0,
              pdpExpired: 1,
              totalBlocked: 2,
            ),
            receiptPolicy: const SovereignReportReceiptPolicy(
              generatedReports: 2,
              trackedConfigurationReports: 1,
              legacyConfigurationReports: 1,
              fullyIncludedReports: 0,
              reportsWithOmittedSections: 1,
              omittedAiDecisionLogReports: 1,
              omittedGuardMetricsReports: 1,
              standardBrandingReports: 1,
              defaultPartnerBrandingReports: 0,
              customBrandingOverrideReports: 1,
              governanceHandoffReports: 1,
              routineReviewReports: 1,
              executiveSummary:
                  '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy',
              brandingExecutiveSummary:
                  '1 receipt used custom branding override',
              investigationExecutiveSummary:
                  '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
              headline: '1 generated reports omitted sections',
              summaryLine:
                  'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1 • Standard branding 1 • Default partner branding 0 • Custom branding 1',
              latestReportSummary:
                  'CLIENT-1/SITE-1 2026-03 omitted AI Decision Log, Guard Metrics.',
              latestBrandingSummary:
                  'CLIENT-1/SITE-1 2026-03 used standard ONYX branding.',
            ),
            vehicleThroughput: const SovereignReportVehicleThroughput(
              totalVisits: 6,
              completedVisits: 5,
              activeVisits: 1,
              incompleteVisits: 0,
              uniqueVehicles: 6,
              repeatVehicles: 0,
              unknownVehicleEvents: 0,
              peakHourLabel: '23:00-00:00',
              peakHourVisitCount: 3,
              averageCompletedDwellMinutes: 18.5,
              suspiciousShortVisitCount: 0,
              loiteringVisitCount: 0,
              workflowHeadline:
                  '5 completed visits reached EXIT • 1 active visit remains in SERVICE',
              summaryLine:
                  'Visits 6 • Entry 6 • Completed 5 • Active 1 • Incomplete 0 • Unique 6 • Avg dwell 18.5m • Peak 23:00-00:00 (3)',
            ),
            partnerProgression: SovereignReportPartnerProgression(
              dispatchCount: 2,
              declarationCount: 5,
              acceptedCount: 2,
              onSiteCount: 1,
              allClearCount: 1,
              cancelledCount: 0,
              workflowHeadline:
                  '1 partner dispatch reached ALL CLEAR • 1 partner dispatch remains ON SITE',
              performanceHeadline: '1 strong response • 1 on-track response',
              slaHeadline: 'Avg accept 5.0m • Avg on site 12.0m',
              summaryLine:
                  'Dispatches 2 • Declarations 5 • Accept 2 • On site 1 • All clear 1 • Cancelled 0',
              scopeBreakdowns: [
                SovereignReportPartnerScopeBreakdown(
                  clientId: 'CLIENT-1',
                  siteId: 'SITE-1',
                  dispatchCount: 2,
                  declarationCount: 5,
                  latestStatus: PartnerDispatchStatus.onSite,
                  latestOccurredAtUtc: DateTime.utc(2026, 3, 9, 23, 44),
                  summaryLine:
                      'Dispatches 2 • Declarations 5 • Latest ON SITE @ 2026-03-09T23:44:00.000Z',
                ),
              ],
              dispatchChains: [
                SovereignReportPartnerDispatchChain(
                  dispatchId: 'DSP-1',
                  clientId: 'CLIENT-1',
                  siteId: 'SITE-1',
                  partnerLabel: 'Partner Alpha',
                  declarationCount: 3,
                  latestStatus: PartnerDispatchStatus.allClear,
                  latestOccurredAtUtc: DateTime.utc(2026, 3, 9, 23, 20),
                  dispatchCreatedAtUtc: DateTime.utc(2026, 3, 9, 23, 0),
                  acceptedAtUtc: DateTime.utc(2026, 3, 9, 23, 5),
                  onSiteAtUtc: DateTime.utc(2026, 3, 9, 23, 12),
                  allClearAtUtc: DateTime.utc(2026, 3, 9, 23, 20),
                  acceptedDelayMinutes: 5.0,
                  onSiteDelayMinutes: 12.0,
                  scoreLabel: 'STRONG',
                  scoreReason:
                      'Partner reached ALL CLEAR inside target acceptance and on-site windows.',
                  workflowSummary:
                      'ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)',
                ),
              ],
            ),
          ),
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-08',
              generatedAtUtc: DateTime.utc(2026, 3, 8, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 7, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 8, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 38,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 10,
                humanOverrides: 2,
                overrideReasons: {'FALSE_ALARM': 2},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 4,
                driftDetected: 0,
                avgMatchScore: 91.0,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              receiptPolicy: const SovereignReportReceiptPolicy(
                generatedReports: 1,
                trackedConfigurationReports: 1,
                legacyConfigurationReports: 0,
                fullyIncludedReports: 1,
                reportsWithOmittedSections: 0,
                omittedAiDecisionLogReports: 0,
                omittedGuardMetricsReports: 0,
                standardBrandingReports: 1,
                defaultPartnerBrandingReports: 0,
                customBrandingOverrideReports: 0,
                governanceHandoffReports: 0,
                routineReviewReports: 1,
                executiveSummary:
                    '1 client-facing receipt used full tracked policy',
                brandingExecutiveSummary:
                    '1 receipt used standard ONYX branding',
                headline: 'All generated reports included every section',
                summaryLine:
                    'Reports 1 • Tracked 1 • Legacy 0 • Full 1 • Omitted 0 • AI log omitted 0 • Guard metrics omitted 0 • Standard branding 1 • Default partner branding 0 • Custom branding 0',
                latestReportSummary:
                    'CLIENT-1/SITE-1 2026-03 included all configured sections.',
                latestBrandingSummary:
                    'CLIENT-1/SITE-1 2026-03 used standard ONYX branding.',
              ),
            ),
          ],
          morningSovereignReportAutoStatusLabel:
              'Auto generated for shift ending 2026-03-09. Next generation runs at 06:00 local.',
          onGenerateMorningSovereignReport: () async {},
          onOpenGuardSync: () {
            openCount += 1;
          },
          onClearGuardOutcomePolicyTelemetry: () {
            clearPolicyCount += 1;
          },
          guardFailureAlertThreshold: 1,
          guardQueuePressureAlertThreshold: 25,
          guardStaleSyncAlertMinutes: 10,
        ),
      ),
    );

    expect(find.text('Guard Sync Health'), findsOneWidget);
    expect(find.text('Failures'), findsOneWidget);
    expect(find.text('Queue Pressure'), findsOneWidget);
    expect(find.text('Stale Sync'), findsOneWidget);
    expect(find.text('Local Only'), findsOneWidget);
    expect(find.text('Policy Denied'), findsOneWidget);
    expect(
      find.text(
        '5 completed visits reached EXIT • 1 active visit remains in SERVICE',
      ),
      findsOneWidget,
    );
    expect(find.text('Receipt policy'), findsOneWidget);
    expect(
      find.text(
        '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy • 1 receipt used custom branding override • 1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
      ),
      findsOneWidget,
    );
    expect(find.text('Receipt policy trend'), findsOneWidget);
    expect(
      find.text(
        'SLIPPING • Latest receipt fell back to legacy policy capture.',
      ),
      findsOneWidget,
    );
    expect(find.text('Receipt investigation'), findsOneWidget);
    expect(
      find.text(
        '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
      ),
      findsWidgets,
    );
    expect(find.text('Receipt investigation trend'), findsOneWidget);
    expect(
      find.text(
        'OVERSIGHT RISING • Latest receipt reviews introduced Governance handoffs above recent routine baseline.',
      ),
      findsOneWidget,
    );
    expect(find.text('Partner progression'), findsOneWidget);
    expect(
      find.text('1 strong response • 1 on-track response'),
      findsOneWidget,
    );
    expect(find.text('Diagnostics and coaching telemetry'), findsOneWidget);
    await tester.ensureVisible(find.text('Diagnostics and coaching telemetry'));
    await tester.tap(find.text('Diagnostics and coaching telemetry'));
    await tester.pumpAndSettle();
    expect(find.text('Policy denied'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Denied (24h)'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Denied (7d)'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Coaching Ack'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Coaching Snooze'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Snooze Expiry'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Recent Coaching Telemetry'), findsOneWidget);
    expect(find.textContaining('acknowledged @ sync by guard'), findsOneWidget);
    expect(find.textContaining('Policy denied (latest):'), findsOneWidget);
    expect(find.text('Advanced export and share'), findsOneWidget);
    expect(find.text('Morning Sovereign Report'), findsOneWidget);
    expect(find.text('Vehicle throughput'), findsOneWidget);
    await tester.ensureVisible(find.text('Advanced export and share'));
    await tester.tap(find.text('Advanced export and share'));
    await tester.pumpAndSettle();
    expect(find.text('Copy Policy Telemetry JSON'), findsOneWidget);
    expect(find.text('Copy Policy Telemetry CSV'), findsOneWidget);
    expect(find.text('Download Policy JSON'), findsOneWidget);
    expect(find.text('Download Policy CSV'), findsOneWidget);
    expect(find.text('Share Policy Pack'), findsOneWidget);
    expect(find.text('Copy Coaching Telemetry JSON'), findsOneWidget);
    expect(find.text('Copy Coaching Telemetry CSV'), findsOneWidget);
    expect(find.text('Download Coaching JSON'), findsOneWidget);
    expect(find.text('Share Coaching Pack'), findsOneWidget);
    expect(
      find.text('Generation and delivery controls moved to Governance screen.'),
      findsOneWidget,
    );
    expect(find.text('Generate Now'), findsNothing);
    expect(find.text('Copy Morning JSON'), findsNothing);
    expect(find.text('Copy Morning CSV'), findsNothing);
    expect(find.text('Download Morning JSON'), findsNothing);
    expect(find.text('Download Morning CSV'), findsNothing);
    expect(find.text('Share Morning Pack'), findsNothing);
    expect(find.text('Email Morning Report'), findsNothing);
    expect(find.text('Recent Failure Trace'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(
      find.textContaining('Event panicTriggered seq 44: event sync timeout'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Media guard-incident-media: upload timeout'),
      findsOneWidget,
    );
    expect(find.text('Copy Failure Trace'), findsOneWidget);
    expect(find.text('Download Failure Trace'), findsOneWidget);
    expect(find.text('Share Failure Trace'), findsOneWidget);
    expect(find.text('Email Failure Trace'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Guard Sync'));
    await tester.tap(find.text('Open Guard Sync'));
    await tester.pumpAndSettle();
    expect(openCount, 1);
    await tester.ensureVisible(find.text('Clear Policy Telemetry'));
    await tester.tap(find.text('Clear Policy Telemetry'));
    await tester.pumpAndSettle();
    expect(clearPolicyCount, 1);
  });

  testWidgets('dashboard guard sync card respects alert thresholds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: InMemoryEventStore(),
          guardSyncBackendEnabled: true,
          guardSyncInFlight: false,
          guardSyncQueueDepth: 24,
          guardPendingEvents: 1,
          guardPendingMedia: 0,
          guardFailedEvents: 1,
          guardFailedMedia: 0,
          guardLastSuccessfulSyncAtUtc: DateTime.now().toUtc().subtract(
            const Duration(minutes: 9),
          ),
          guardFailureAlertThreshold: 2,
          guardQueuePressureAlertThreshold: 25,
          guardStaleSyncAlertMinutes: 10,
        ),
      ),
    );

    expect(find.text('Guard Sync Health'), findsOneWidget);
    expect(find.text('Failures'), findsNothing);
    expect(find.text('Queue Pressure'), findsNothing);
    expect(find.text('Stale Sync'), findsNothing);
    expect(find.text('Local Only'), findsNothing);
  });

  testWidgets('dashboard shows triage posture summary', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      IntelligenceReceived(
        eventId: 'E-INT-1',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 12, 0),
        intelligenceId: 'INT-1',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'article-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Armed suspects near gate B',
        summary: 'Vehicle and suspect activity near perimeter gate',
        riskScore: 84,
        canonicalHash: 'hash-1',
      ),
    );
    store.append(
      IntelligenceReceived(
        eventId: 'E-INT-2',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 12, 2),
        intelligenceId: 'INT-2',
        provider: 'community-feed',
        sourceType: 'community',
        externalId: 'community-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Community confirms suspects near gate B',
        summary: 'Repeat suspicious vehicle and armed suspects at perimeter',
        riskScore: 72,
        canonicalHash: 'hash-2',
      ),
    );
    store.append(
      DecisionCreated(
        eventId: 'DEC-1',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 6, 12, 5),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(eventStore: store)),
    );

    expect(find.text('A 0 • W 1 • DC 1 • Esc 1'), findsOneWidget);
    expect(find.textContaining('Top triage signals:'), findsOneWidget);
  });
}
